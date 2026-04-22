# ============================================================
# External Secrets Operator — Pod Identity 설정
#
# Platform Team이 1회 실행. OEM사와 무관.
# 사전 요건: EKS Pod Identity Agent 애드온이 클러스터에 설치되어 있어야 함.
#   aws eks create-addon --cluster-name <CLUSTER> --addon-name eks-pod-identity-agent
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================
# 1. IAM Policy — Secrets Manager + SSM Parameter Store 접근
# ============================================================
resource "aws_iam_policy" "external_secrets" {
  name        = "${var.eks_cluster_name}-external-secrets"
  description = "External Secrets Operator가 Secrets Manager/SSM에서 시크릿을 읽기 위한 정책"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:sim-platform/*"
      },
      {
        Sid    = "SSMParameterRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter/sim-platform/*"
      },
    ]
  })

  tags = {
    ManagedBy = "terraform"
    Component = "external-secrets"
  }
}

# ============================================================
# 2. Pod Identity — ESO ServiceAccount ↔ IAM Role 매핑
# ============================================================
module "eso_pod_identity" {
  source = "../modules/pod-identity"

  role_name            = "${var.eks_cluster_name}-external-secrets"
  cluster_name         = var.eks_cluster_name
  namespace            = "external-secrets"
  service_account_name = "external-secrets"
  policy_arns          = [aws_iam_policy.external_secrets.arn]

  tags = {
    ManagedBy = "terraform"
    Component = "external-secrets"
  }
}

# ============================================================
# 3. Helm Release — External Secrets Operator
# ============================================================
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  version          = "0.12.1"

  set = [
    { name = "serviceAccount.name", value = "external-secrets" },
  ]

  depends_on = [module.eso_pod_identity]
}
