# Changelog

[![English](https://img.shields.io/badge/lang-English-blue.svg)](#english)
[![한국어](https://img.shields.io/badge/lang-한국어-green.svg)](#한국어)

---

# English

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Architecture documentation with system diagrams ([docs/architecture.md](docs/architecture.md))
- Developer onboarding guide ([docs/onboarding.md](docs/onboarding.md))
- ADR and runbook templates for standardized documentation

### Changed

- Convert README to bilingual format (English/Korean) with shields.io badges

## [0.1.0] - 2026-04-22

### Added

- Initial Terraform platform with three modules: ACM, Route 53, Helm Release
- Helm chart deploying 6 simulator components per user namespace (nginx-proxy, simulator-server, simulator-can, simulator-vehicle, target-android, target-cluster)
- Two-phase apply pattern for ALB DNS resolution
- OEM-shared ALB via `alb.ingress.kubernetes.io/group.name` annotation
- Hybrid Node support with optional nodeSelector and toleration
- Per-user namespace isolation using `sim-{oem}-{user}` naming convention
- Wildcard ACM certificates with automated Route 53 DNS validation
- Environment wrapper pattern for managing multiple deployment targets (`envs/dev/`)
- Operational runbooks: full deployment, OEM/User management, troubleshooting, teardown
- Customer delivery guide ([GUIDE.md](GUIDE.md))
- Pod security context defaults: non-root execution, read-only filesystem, drop ALL capabilities
- PodDisruptionBudget support for production workloads
- Per-component image tag and replica configuration via `oem_users` variable

[Unreleased]: https://github.com/comeddy/eks-hybrid-sim/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/comeddy/eks-hybrid-sim/releases/tag/v0.1.0

---

# 한국어

이 프로젝트의 모든 주요 변경 사항은 이 파일에 기록됩니다.

이 문서는 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 기반으로 하며,
[Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따릅니다.

## [Unreleased]

### Added

- 시스템 다이어그램을 포함한 아키텍처 문서 ([docs/architecture.md](docs/architecture.md))
- 개발자 온보딩 가이드 ([docs/onboarding.md](docs/onboarding.md))
- 표준화된 문서 작성을 위한 ADR 및 Runbook 템플릿

### Changed

- README를 shields.io 뱃지가 포함된 이중 언어 형식(영어/한국어)으로 변환

## [0.1.0] - 2026-04-22

### Added

- ACM, Route 53, Helm Release 세 모듈로 구성된 초기 Terraform 플랫폼
- 사용자 네임스페이스별 6개 시뮬레이터 컴포넌트를 배포하는 Helm 차트 (nginx-proxy, simulator-server, simulator-can, simulator-vehicle, target-android, target-cluster)
- ALB DNS 해결을 위한 2단계 apply 패턴
- `alb.ingress.kubernetes.io/group.name` 어노테이션을 통한 OEM별 ALB 공유
- 선택적 nodeSelector 및 toleration을 포함하는 Hybrid Node 지원
- `sim-{oem}-{user}` 명명 규칙을 사용하는 사용자별 네임스페이스 격리
- Route 53 DNS 검증을 자동화하는 와일드카드 ACM 인증서
- 복수 배포 환경 관리를 위한 환경 래퍼 패턴 (`envs/dev/`)
- 운영 Runbook: 전체 배포, OEM/User 관리, 장애 진단, 리소스 정리
- 고객 전달용 통합 가이드 ([GUIDE.md](GUIDE.md))
- Pod 보안 컨텍스트 기본값: 비루트 실행, 읽기 전용 파일시스템, 모든 capability 제거
- 프로덕션 워크로드용 PodDisruptionBudget 지원
- `oem_users` 변수를 통한 컴포넌트별 이미지 태그 및 레플리카 설정

[Unreleased]: https://github.com/comeddy/eks-hybrid-sim/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/comeddy/eks-hybrid-sim/releases/tag/v0.1.0
