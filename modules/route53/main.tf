# ============================================================
# Route 53 와일드카드 Alias 레코드 → ALB
# *.{oem_id}.{base_domain}  →  ALB
# ============================================================

resource "aws_route53_record" "wildcard_alias" {
  count = var.alb_dns_name != "" ? 1 : 0

  zone_id = var.zone_id
  name    = "*.${var.oem_id}.${var.base_domain}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
