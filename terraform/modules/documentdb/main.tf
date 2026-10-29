# AWS DocumentDB cluster used as an external MongoDB-compatible database instead of the chart's
# bundled MongoDB (mongodb.enabled: false): dedicated subnet group, a security group scoped to the
# worker nodes only, a generated master password kept in Secrets Manager, the cluster, and 1+ instances.
# Nothing here is reachable from outside the VPC.

resource "random_password" "master" {
  length  = 32
  special = false # the password is embedded in a mongodb:// URI — keep it URI-safe
}

resource "aws_secretsmanager_secret" "master" {
  name                    = "${var.name_prefix}-documentdb-master"
  description             = "DocumentDB master credentials for ${var.name_prefix}"
  recovery_window_in_days = 0

  tags = {
    Name                       = "${var.name_prefix}-documentdb-master"
    "duplocloud.net/component" = "helpdesk-documentdb"
  }
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id = aws_secretsmanager_secret.master.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    host     = aws_docdb_cluster.this.endpoint
    port     = aws_docdb_cluster.this.port
  })
}

resource "aws_docdb_subnet_group" "this" {
  name        = "${var.name_prefix}-docdb-subnet-group"
  description = "Private subnets for ${var.name_prefix} DocumentDB"
  subnet_ids  = var.private_subnet_ids

  tags = { Name = "${var.name_prefix}-docdb-subnet-group" }
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-docdb-sg"
  description = "DocumentDB access for ${var.name_prefix} - inbound 27017 from the Helpdesk worker nodes only"
  vpc_id      = var.vpc_id

  # Pods use the node's primary-ENI security groups (VPC CNI, no SG-for-pods), so allowing the node
  # SGs is what lets the backend, duplo-agent and collector pods reach the cluster.
  ingress {
    description     = "DocumentDB access from Helpdesk worker nodes"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = var.source_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-docdb-sg" }
}

resource "aws_docdb_cluster" "this" {
  cluster_identifier           = "${var.name_prefix}-docdb"
  engine                       = "docdb"
  engine_version               = var.engine_version
  port                         = 27017
  master_username              = var.master_username
  master_password              = random_password.master.result
  db_subnet_group_name         = aws_docdb_subnet_group.this.name
  vpc_security_group_ids       = [aws_security_group.this.id]
  storage_encrypted            = true
  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  deletion_protection          = var.deletion_protection

  # Equivalent of the CloudFormation template's DeletionPolicy: Snapshot.
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-docdb-final"

  tags = {
    Name                       = "${var.name_prefix}-docdb"
    "duplocloud.net/component" = "helpdesk-documentdb"
  }
}

resource "aws_docdb_cluster_instance" "this" {
  count              = var.instance_count
  identifier         = "${var.name_prefix}-docdb-instance-${count.index + 1}"
  cluster_identifier = aws_docdb_cluster.this.id
  instance_class     = var.instance_class

  tags = { Name = "${var.name_prefix}-docdb-instance-${count.index + 1}" }
}

locals {
  # tls/retryWrites are mandatory for DocumentDB. tlsInsecure=true is required too: DocumentDB's cert is
  # signed by Amazon's own CA, which isn't in the backend image's trust store, and the chart can't mount a
  # CA bundle yet — without it the .NET driver fails with "certificate chain: PartialChain"
  # (tlsAllowInvalidCertificates does NOT fix it). Traffic is still encrypted; reachability is limited by
  # aws_security_group.this. Replace with tlsCAFile=... once the chart supports mounting global-bundle.pem.
  connection_string = "mongodb://${var.master_username}:${random_password.master.result}@${aws_docdb_cluster.this.endpoint}:${aws_docdb_cluster.this.port}/?tls=true&retryWrites=false&tlsInsecure=true"
}
