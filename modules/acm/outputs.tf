output "certificate_arn" {
  description = "발급된 ACM 인증서 ARN"
  value       = aws_acm_certificate.wildcard.arn
}

output "domain_name" {
  description = "인증서 도메인"
  value       = aws_acm_certificate.wildcard.domain_name
}
