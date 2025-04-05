# Configuration CloudWatch pour la journalisation
resource "aws_cloudwatch_log_group" "mt5_logs" {
  name              = "/ec2/mt5-instance"
  retention_in_days = 30

  tags = {
    Name        = "MT5-Logs"
    Environment = "Production"
  }
}

# IAM Role pour permettre à l'instance EC2 d'envoyer des logs à CloudWatch
resource "aws_iam_role" "mt5_cloudwatch_role" {
  name = "mt5-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "MT5-CloudWatch-Role"
  }
}

# Politique permettant d'envoyer des logs à CloudWatch, d'accéder à S3 et à Secrets Manager
resource "aws_iam_policy" "mt5_cloudwatch_policy" {
  name        = "mt5-cloudwatch-policy"
  description = "Permet d'envoyer des logs à CloudWatch, d'accéder à S3 et à Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "ec2:DescribeTags"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::ea-trading-bucket",
          "arn:aws:s3:::ea-trading-bucket/*"
        ]
      },
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:ListSecrets"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attacher la politique au rôle
resource "aws_iam_role_policy_attachment" "mt5_cloudwatch_attachment" {
  role       = aws_iam_role.mt5_cloudwatch_role.name
  policy_arn = aws_iam_policy.mt5_cloudwatch_policy.arn
}

# Profil d'instance pour attacher le rôle à l'instance EC2
resource "aws_iam_instance_profile" "mt5_instance_profile" {
  name = "mt5-instance-profile"
  role = aws_iam_role.mt5_cloudwatch_role.name
}
