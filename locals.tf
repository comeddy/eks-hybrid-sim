# ============================================================
# oem_users 맵을 flat map으로 변환
# key = "hyundai/user-a"  →  { oem_id, user_id, services }
# ============================================================
locals {
  zone_id = var.route53_zone_id != "" ? var.route53_zone_id : data.aws_route53_zone.this[0].zone_id

  oem_ids = keys(var.oem_users)

  oem_user_flat = merge([
    for oem_id, oem in var.oem_users : {
      for user_id, user in oem.users :
      "${oem_id}/${user_id}" => {
        oem_id   = oem_id
        user_id  = user_id
        services = user.services
      }
    }
  ]...)
}

data "aws_route53_zone" "this" {
  count = var.route53_zone_id == "" ? 1 : 0
  name  = "${var.base_domain}."
}
