# ============================================================
# 1. OEM별 ACM 와일드카드 인증서 + DNS 검증
# ============================================================
module "acm" {
  source   = "./modules/acm"
  for_each = toset(local.oem_ids)

  oem_id      = each.key
  base_domain = var.base_domain
  zone_id     = local.zone_id

  tags = {
    OEM       = each.key
    ManagedBy = "terraform"
    Project   = "simulator-platform"
  }
}

# ============================================================
# 2. User별 Helm Release 배포
#    DNS는 External-DNS가 Ingress annotation으로 자동 관리
# ============================================================
module "helm_release" {
  source   = "./modules/helm-release"
  for_each = local.oem_user_flat

  oem_id  = each.value.oem_id
  user_id = each.value.user_id

  helm_chart_path = var.helm_chart_path
  namespace       = "sim-${each.value.oem_id}-${each.value.user_id}"
  ecr_registry    = var.ecr_registry
  base_domain     = var.base_domain
  acm_cert_arn    = module.acm[each.value.oem_id].certificate_arn

  hybrid_node_enabled    = var.hybrid_node_enabled
  alb_security_group_id = var.alb_security_group_id

  services = each.value.services

  depends_on = [module.acm]
}
