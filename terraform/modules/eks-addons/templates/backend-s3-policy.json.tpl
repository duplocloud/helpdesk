{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "${s3_bucket_arn}",
                "${s3_bucket_arn}/*",
                "${s3_userdata_bucket_arn}",
                "${s3_userdata_bucket_arn}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::${account_id}:role/${cluster_name}-node-role"
        },
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:InvokeModel",
                "bedrock:InvokeModelWithResponseStream",
                "bedrock:ListFoundationModelAgreementOffers",
                "bedrock:CreateFoundationModelAgreement",
                "bedrock:ListFoundationModels",
                "bedrock:GetFoundationModel",
                "bedrock:ListCustomModels",
                "bedrock:GetCustomModel",
                "bedrock:CreateModelInvocationJob",
                "bedrock:GetModelInvocationJob",
                "bedrock:ListModelInvocationJobs",
                "bedrock:StopModelInvocationJob"
            ],
            "Resource": "*"
        }
    ]
}
