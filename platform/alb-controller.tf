# ============================================================
# AWS Load Balancer Controller — Pod Identity 설정
# ============================================================

data "http" "alb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.12.0/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb_controller" {
  name        = "${var.eks_cluster_name}-alb-controller"
  description = "AWS Load Balancer Controller IAM Policy"
  policy      = data.http.alb_controller_policy.response_body

  tags = {
    ManagedBy = "terraform"
    Component = "alb-controller"
  }
}

module "alb_controller_pod_identity" {
  source = "../modules/pod-identity"

  role_name            = "${var.eks_cluster_name}-alb-controller"
  cluster_name         = var.eks_cluster_name
  namespace            = "kube-system"
  service_account_name = "aws-load-balancer-controller"
  policy_arns          = [aws_iam_policy.alb_controller.arn]

  tags = {
    ManagedBy = "terraform"
    Component = "alb-controller"
  }
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.12.0"

  set = [
    { name = "clusterName", value = var.eks_cluster_name },
    { name = "serviceAccount.name", value = "aws-load-balancer-controller" },
    { name = "region", value = data.aws_region.current.id },
    { name = "vpcId", value = data.aws_eks_cluster.this.vpc_config[0].vpc_id },
  ]

  depends_on = [module.alb_controller_pod_identity]
}
