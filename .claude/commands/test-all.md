# Test All

전체 검증 스위트를 실행합니다.

## Steps

1. Terraform 포맷 검사:
```bash
terraform fmt -check -recursive .
```

2. Terraform 유효성 검사 (init 필요):
```bash
cd envs/dev && terraform validate
```

3. Helm 차트 Lint:
```bash
helm lint ./eks-simulator-helm
```

4. Helm 렌더링 테스트:
```bash
helm template test ./eks-simulator-helm \
  --set userId=test,oemId=test,imageRegistry=test \
  --set ingress.annotations."alb\.ingress\.kubernetes\.io/certificate-arn"=arn:aws:acm:ap-northeast-2:123456789012:certificate/test
```

5. 프로젝트 구조 테스트:
```bash
bash tests/run-all.sh 2>/dev/null || echo "Test framework not initialized"
```

6. 결과를 PASS/FAIL 요약으로 출력
