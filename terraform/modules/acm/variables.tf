variable "helpdesk_dns" {
  description = "Primary DNS name for the helpdesk (e.g. ai.example.com)"
  type        = string
}

variable "helpdesk_xterm_dns" {
  description = "DNS name for the helpdesk xterm service"
  type        = string
}

variable "route53_zone_name" {
  description = "Route53 hosted zone name (e.g. example.com)"
  type        = string
}
