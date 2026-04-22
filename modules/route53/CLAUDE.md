# modules/route53

OEM별 와일드카드 DNS A(Alias) 레코드를 생성하여 ALB로 트래픽을 라우팅하는 모듈.

## Resources

- `aws_route53_record.wildcard_alias`: `*.{oem_id}.{base_domain}` → ALB Alias 레코드 (조건부 생성)

## Inputs

- `oem_id`: OEM 식별자
- `base_domain`: 기본 도메인
- `zone_id`: Route 53 Hosted Zone ID
- `alb_dns_name`: ALB DNS (빈 문자열이면 레코드 미생성)
- `alb_zone_id`: ALB Hosted Zone ID

## Behavior

- `alb_dns_name`이 빈 문자열이면 `count = 0`으로 레코드가 생성되지 않음
- 2차 apply에서 `alb_dns_overrides` 변수를 통해 ALB DNS가 주입됨
- `depends_on = [module.acm]`으로 인증서 생성 후 실행
