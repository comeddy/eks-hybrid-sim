# Changelog

[![English](https://img.shields.io/badge/lang-English-blue)](#english) [![Korean](https://img.shields.io/badge/lang-한국어-green)](#한국어)

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

# English

## [Unreleased]

### Added
- Claude Code project structure (CLAUDE.md, hooks, skills, commands, agents)
- Bilingual architecture documentation (docs/architecture.md)
- Onboarding guide (docs/onboarding.md)
- ADR and runbook templates
- Module-level CLAUDE.md files for all Terraform modules and Helm chart
- Test framework for project structure validation
- EditorConfig for consistent formatting

### Changed
- README.md converted to bilingual format (English/Korean)

## [0.1.0] - 2025-04-22

### Added
- Initial Terraform platform with three modules (ACM, Route 53, Helm Release)
- Helm chart with 6 simulator components (nginx-proxy, simulator-server, simulator-can, simulator-vehicle, target-android, target-cluster)
- Two-phase apply pattern for ALB DNS resolution
- OEM-shared ALB via Ingress group.name annotation
- Hybrid Node support with optional nodeSelector and toleration
- Per-user namespace isolation (`sim-{oem}-{user}`)
- Wildcard ACM certificates with DNS validation
- Environment wrapper pattern (`envs/dev/`)
- Operational runbooks (full-deployment, add-oem-user, troubleshooting, teardown)
- Installation runbook with variable substitution guide
- Customer delivery guide (GUIDE.md)
- Pod security context defaults (non-root, read-only filesystem, drop ALL)
- PodDisruptionBudget support

---

# 한국어

## [Unreleased]

### Added
- Claude Code 프로젝트 구조 (CLAUDE.md, 훅, 스킬, 커맨드, 에이전트)
- 이중언어 아키텍처 문서 (docs/architecture.md)
- 온보딩 가이드 (docs/onboarding.md)
- ADR 및 Runbook 템플릿
- 모든 Terraform 모듈 및 Helm 차트에 모듈별 CLAUDE.md 파일 추가
- 프로젝트 구조 검증용 테스트 프레임워크
- 일관된 포맷팅을 위한 EditorConfig

### Changed
- README.md를 이중언어 형식(영어/한국어)으로 변환

## [0.1.0] - 2025-04-22

### Added
- 세 모듈로 구성된 초기 Terraform 플랫폼 (ACM, Route 53, Helm Release)
- 6개 시뮬레이터 컴포넌트를 포함하는 Helm 차트 (nginx-proxy, simulator-server, simulator-can, simulator-vehicle, target-android, target-cluster)
- ALB DNS 해결을 위한 2단계 apply 패턴
- Ingress group.name 어노테이션을 통한 OEM별 ALB 공유
- 선택적 nodeSelector 및 toleration을 포함하는 Hybrid Node 지원
- 사용자별 네임스페이스 격리 (`sim-{oem}-{user}`)
- DNS 검증을 포함하는 와일드카드 ACM 인증서
- 환경 래퍼 패턴 (`envs/dev/`)
- 운영 Runbook (전체 배포, OEM/User 추가, 장애 진단, 리소스 정리)
- 변수 치환 가이드가 포함된 설치 Runbook
- 고객 전달용 통합 가이드 (GUIDE.md)
- Pod 보안 컨텍스트 기본값 (비루트, 읽기 전용 파일시스템, 모든 capability 제거)
- PodDisruptionBudget 지원

---

[Unreleased]: https://github.com/comeddy/eks-hybrid-sim/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/comeddy/eks-hybrid-sim/releases/tag/v0.1.0
