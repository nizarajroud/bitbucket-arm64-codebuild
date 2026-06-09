variable "bitbucket_workspace" {
  default = "r3d-numerique"
}

variable "bitbucket_workspace_uuid" {
  type        = string
  description = "Bitbucket workspace UUID (without braces)"
}

variable "bitbucket_repo" {
  default = "kikoai-app"
}

# Bitbucket OIDC Provider
resource "aws_iam_openid_connect_provider" "bitbucket" {
  url             = "https://api.bitbucket.org/2.0/workspaces/${var.bitbucket_workspace}/pipelines-config/identity/oidc"
  client_id_list  = ["ari:cloud:bitbucket::workspace/${var.bitbucket_workspace_uuid}"]
  thumbprint_list = ["a031c46782e6e6c662c2c87c76da9aa62ccabd8e"]
}

# IAM Role for Bitbucket Pipelines
resource "aws_iam_role" "bitbucket_pipeline" {
  name = "bitbucket-arm64-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.bitbucket.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "${aws_iam_openid_connect_provider.bitbucket.url}:sub" = "*"
        }
        StringEquals = {
          "${aws_iam_openid_connect_provider.bitbucket.url}:aud" = "ari:cloud:bitbucket::workspace/${var.bitbucket_workspace_uuid}"
        }
      }
    }]
  })
}

# Policy: allow starting and monitoring CodeBuild
resource "aws_iam_role_policy" "bitbucket_codebuild" {
  name = "bitbucket-codebuild-access"
  role = aws_iam_role.bitbucket_pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "codebuild:StartBuild",
        "codebuild:BatchGetBuilds"
      ]
      Resource = "arn:aws:codebuild:${var.aws_region}:${var.aws_account_id}:project/${var.codebuild_project_name}"
    }]
  })
}

output "bitbucket_role_arn" {
  value = aws_iam_role.bitbucket_pipeline.arn
}
