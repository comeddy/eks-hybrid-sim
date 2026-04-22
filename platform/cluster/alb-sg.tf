# ============================================================
# ALB Security Group
#
# 0.0.0.0/0 인바운드 절대 금지.
# CloudFront prefix list만 HTTPS(443) 인바운드 허용.
# ALB → 클러스터 통신은 EKS 클러스터 SG에서 허용.
# ============================================================

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb" {
  name_prefix = "${var.cluster_name}-alb-"
  description = "ALB SG - CloudFront origin only, no 0.0.0.0/0"
  vpc_id      = var.vpc_id

  tags = {
    Name      = "${var.cluster_name}-alb"
    ManagedBy = "terraform"
    Cluster   = var.cluster_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from CloudFront"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
}

resource "aws_vpc_security_group_egress_rule" "alb_to_cluster" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To EKS cluster"
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

# 클러스터 SG에 ALB로부터의 인바운드 허용
resource "aws_vpc_security_group_ingress_rule" "cluster_from_alb" {
  security_group_id            = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description                  = "From ALB"
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}
