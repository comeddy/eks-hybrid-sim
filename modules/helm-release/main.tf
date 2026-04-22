# ============================================================
# Kubernetes Namespace (helm_release 전에 생성)
# ============================================================
resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      "simulator-platform/oem"  = var.oem_id
      "simulator-platform/user" = var.user_id
      "managed-by"              = "terraform"
    }
  }
}

# ============================================================
# Helm Release — simulator-platform chart 배포
# ============================================================
resource "helm_release" "simulator" {
  name      = "${var.oem_id}-${var.user_id}"
  chart     = var.helm_chart_path
  namespace = kubernetes_namespace_v1.this.metadata[0].name

  create_namespace = false
  wait             = false
  wait_for_jobs    = false
  timeout          = 600
  atomic           = false

  set = concat(
    [
      { name = "userId", value = var.user_id },
      { name = "oemId", value = var.oem_id },
      { name = "imageRegistry", value = var.ecr_registry },
      { name = "ingress.baseDomain", value = var.base_domain },
      { name = "ingress.certArn", value = var.acm_cert_arn },
      { name = "hybridNode.enabled", value = tostring(var.hybrid_node_enabled) },
      { name = "ingress.securityGroupId", value = var.alb_security_group_id },
    ],
    # 서비스별 이미지 태그 + replicas (동적 주입)
    flatten([
      for svc_name, svc in var.services : [
        { name = "services.${svc_name}.image.tag", value = svc.image_tag },
        { name = "services.${svc_name}.replicas", value = tostring(svc.replicas) },
      ]
    ])
  )
}
