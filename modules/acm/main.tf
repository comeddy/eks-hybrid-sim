# ============================================================
# ACM 와일드카드 인증서 + DNS 자동 검증
# *.{oem_id}.{base_domain}  (예: *.hyundai.example.com)
# ============================================================

resource "aws_acm_certificate" "wildcard" {
  domain_name       = "*.${var.oem_id}.${var.base_domain}"
  validation_method = "DNS"

  # 인증서 교체 시 서비스 중단 방지
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.oem_id}-wildcard-cert"
  })
}

# --- DNS 검증 레코드 자동 생성 ---
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = var.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 300
  records         = [each.value.record]
  allow_overwrite = true
}

# --- 검증 완료 대기 ---
# 도메인 NS 위임 완료 후 활성화
# resource "aws_acm_certificate_validation" "wildcard" {
#   certificate_arn         = aws_acm_certificate.wildcard.arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
#
#   timeouts {
#     create = "10m"
#   }
# }
