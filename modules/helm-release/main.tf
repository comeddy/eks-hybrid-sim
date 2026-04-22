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

  create_namespace = false   # 위에서 이미 생성
  wait             = false   # 이미지 준비 전 배포 허용
  timeout          = 600     # 10분
  atomic           = false   # 초기 배포 시 롤백 방지

  set = [
    # ---- Core ----
    { name = "userId",        value = var.user_id },
    { name = "oemId",         value = var.oem_id },
    { name = "imageRegistry", value = var.ecr_registry },

    # ---- Ingress / ALB ----
    { name = "ingress.baseDomain",                                                value = var.base_domain },
    { name = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn", value = var.acm_cert_arn },

    # ---- Hybrid Node ----
    { name = "hybridNode.enabled", value = tostring(var.hybrid_node_enabled) },

    # ---- Component image tags ----
    { name = "simulatorCan.tag",         value = var.simulator_can_tag },
    { name = "simulatorServer.tag",      value = var.simulator_server_tag },
    { name = "simulatorServer.replicas", value = tostring(var.simulator_server_replicas) },
    { name = "simulatorVehicle.tag",     value = var.simulator_vehicle_tag },
    { name = "targetAndroid.tag",        value = var.target_android_tag },
    { name = "targetCluster.tag",        value = var.target_cluster_tag },
  ]
}
