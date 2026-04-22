# Release Skill

새 버전 릴리스 절차를 수행합니다.

## Pre-Release Checklist

1. `terraform fmt -check -recursive .` 통과
2. `terraform validate` 통과
3. `helm lint ./eks-simulator-helm` 통과
4. CHANGELOG.md 업데이트 (Unreleased → 버전)
5. Chart.yaml의 `version` / `appVersion` 업데이트
6. README.md 변경사항 반영

## Release Steps

```bash
# 1. 버전 태그 결정
VERSION="v0.2.0"

# 2. Chart.yaml 업데이트
sed -i "s/^version:.*/version: ${VERSION#v}/" eks-simulator-helm/Chart.yaml

# 3. CHANGELOG.md Unreleased → 버전 이동
# [Unreleased] 아래 항목을 [VERSION] - YYYY-MM-DD 섹션으로 이동

# 4. 커밋 및 태그
git add -A
git commit -m "Release $VERSION"
git tag "$VERSION"

# 5. Push
git push origin main --tags
```

## Post-Release

- GitHub Release 생성 (CHANGELOG에서 해당 버전 내용 복사)
- 배포 환경에 `terraform apply` 실행
