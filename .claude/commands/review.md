# Code Review

현재 브랜치의 변경사항을 리뷰합니다.

## Steps

1. 변경된 파일 확인:
```bash
git diff --name-only HEAD~1
git diff --stat
```

2. Terraform 검증:
```bash
terraform fmt -check -recursive .
terraform validate 2>/dev/null || echo "validate requires init"
```

3. Helm 검증:
```bash
helm lint ./eks-simulator-helm
helm template test ./eks-simulator-helm --set userId=test,oemId=test,imageRegistry=test >/dev/null
```

4. 시크릿 스캔:
```bash
git diff HEAD~1 | grep -iP '(password|secret|key|token)\s*=' || echo "No secrets found"
```

5. 변경사항 분석 후 리뷰 결과를 다음 형식으로 출력:
- **Summary**: 변경 요약
- **Risk**: High/Medium/Low + 사유
- **Issues**: 발견된 문제
- **Suggestions**: 개선 제안
