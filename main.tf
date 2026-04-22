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
# 2. OEM별 Route 53 와일드카드 Alias 레코드
#    (ALB DNS는 첫 번째 Helm 릴리스 배포 후 data source로 조회)
# ============================================================
module "route53" {
  source   = "./modules/route53"
  for_each = toset(local.oem_ids)

  oem_id      = each.key
  base_domain = var.base_domain
  zone_id     = local.zone_id

  # ALB DNS는 해당 OEM의 첫 번째 user Ingress에서 가져옴
  # 초기 배포 시 알 수 없으므로 placeholder → 2차 apply에서 갱신
  alb_dns_name    = var.alb_dns_overrides != null ? lookup(var.alb_dns_overrides, each.key, "") : ""
  alb_zone_id     = var.alb_zone_id

  depends_on = [module.acm]
}

# ============================================================
# 3. User별 Helm Release 배포
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

  hybrid_node_enabled = var.hybrid_node_enabled

  # 컴포넌트별 이미지 태그
  simulator_can_tag     = each.value.simulator_can_tag
  simulator_server_tag  = each.value.simulator_server_tag
  simulator_vehicle_tag = each.value.simulator_vehicle_tag
  target_android_tag    = each.value.target_android_tag
  target_cluster_tag    = each.value.target_cluster_tag

  simulator_server_replicas = each.value.simulator_server_replicas

  depends_on = [module.acm]
}
