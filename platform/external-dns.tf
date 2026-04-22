# ============================================================
# External-DNS — Pod Identity 설정
# ============================================================

resource "aws_iam_policy" "external_dns" {
  name        = "${var.eks_cluster_name}-external-dns"
  description = "External-DNS가 Route53 레코드를 관리하기 위한 정책"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Route53Change"
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = ["arn:aws:route53:::hostedzone/*"]
      },
      {
        Sid    = "Route53List"
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource",
        ]
        Resource = ["*"]
      },
    ]
  })

  tags = {
    ManagedBy = "terraform"
    Component = "external-dns"
  }
}

module "external_dns_pod_identity" {
  source = "../modules/pod-identity"

  role_name            = "${var.eks_cluster_name}-external-dns"
  cluster_name         = var.eks_cluster_name
  namespace            = "kube-system"
  service_account_name = "external-dns"
  policy_arns          = [aws_iam_policy.external_dns.arn]

  tags = {
    ManagedBy = "terraform"
    Component = "external-dns"
  }
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.15.2"

  set = [
    { name = "provider.name", value = "aws" },
    { name = "policy", value = "sync" },
    { name = "registry", value = "txt" },
    { name = "txtOwnerId", value = var.eks_cluster_name },
    { name = "txtPrefix", value = "edns-" },
    { name = "domainFilters[0]", value = var.base_domain },
    { name = "serviceAccount.name", value = "external-dns" },
  ]

  depends_on = [module.external_dns_pod_identity]
}
