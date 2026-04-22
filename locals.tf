# ============================================================
# oem_users 맵을 flat 한 리스트로 변환
# key = "hyundai/user-a"  →  { oem_id, user_id, ...tags }
# ============================================================
locals {
  # Route 53 Zone ID: 변수로 넘겼으면 그대로, 아니면 data source 조회
  zone_id = var.route53_zone_id != "" ? var.route53_zone_id : data.aws_route53_zone.this[0].zone_id

  # OEM ID 목록 (ACM / Route53 모듈 반복용)
  oem_ids = keys(var.oem_users)

  # flat map: "oem/user" → 속성
  oem_user_flat = merge([
    for oem_id, oem in var.oem_users : {
      for user_id, user in oem.users :
      "${oem_id}/${user_id}" => merge(user, {
        oem_id  = oem_id
        user_id = user_id
      })
    }
  ]...)
}

# Route 53 Zone 자동 조회 (zone_id 미지정 시)
data "aws_route53_zone" "this" {
  count = var.route53_zone_id == "" ? 1 : 0
  name  = "${var.base_domain}."
}
