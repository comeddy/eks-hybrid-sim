# modules/acm

OEM별 ACM 와일드카드 인증서를 생성하고 Route 53 DNS 검증 레코드를 자동 생성하는 모듈.

## Resources

- `aws_acm_certificate.wildcard`: `*.{oem_id}.{base_domain}` 와일드카드 인증서
- `aws_route53_record.cert_validation`: DNS 검증 CNAME 레코드

## Inputs

- `oem_id`: OEM 식별자 (인증서 도메인에 사용)
- `base_domain`: 기본 도메인
- `zone_id`: Route 53 Hosted Zone ID

## Outputs

- `certificate_arn`: Helm Release 모듈에서 ALB Ingress에 사용

## Notes

- `aws_acm_certificate_validation`은 주석 처리됨 (NS 위임 미완료 시 무한 대기 방지)
- `lifecycle.create_before_destroy`로 인증서 교체 시 서비스 중단 방지
