# Real Visor Overlay

Assetto Corsa용 CSP Lua 바이저 렌더러. KN5 바이저·유리 레이어와 RainFX를 렌더링한다.
앱 표시 버전은0.6.0이다. 이 번호만으로 실험 단계나 파일 조합을 식별할 수 없으므로
공유·설치본에는 Git 커밋과 함께 제공한 자산 묶음을 같이 기록한다.

## 처음 읽을 문서

2026-10-25 정리 이후: [CSP 기반 새 구현안](docs/RAINFX_CSP_REDESIGN.md)을 새 개발의
기준으로 제안한다. 기존 P0의 승인을 전제로 하지 않는다. 새 렌더러는 아직 미구현이다.
[정리 기록](docs/development/cleanup_20261025/report.json)에 제거·보관 범위가 있다.
구형 진단 메뉴38개와 별도 설치 probe13개를 정리했다. 기존 앱과 P0 실행 의존성은 보존했다.

| 목적 | 진입점 |
| --- | --- |
| 현재 구현·검증 범위 확인 | [현재 상태](docs/guide/CURRENT_STATUS.md) |
| 새 PC 또는 게임 폴더에 설치 | [설치·업데이트](docs/guide/INSTALLATION.md) |
| 앱 사용, P0 실행, 설정·문제 보고 | [운용](docs/guide/OPERATIONS.md) |
| 코드 수정, 데이터 흐름, 검사 | [개발](docs/guide/DEVELOPMENT.md) |
| 백업, 복구, 자산 변경·인계 | [유지보수](docs/guide/MAINTENANCE.md) |
| 상세 실험·설계 근거 찾기 | [기존 문서 색인](docs/README.md) |

현재 문서 기준일: **2026-10-25, regional pool return 연결 이후**.
소스와 이 안내서를 함께 보관한다. 과거 s번호 문서는 해당 단계의 기록이며,
그 안의 “current”, “next”, “pending”을 오늘의 상태로 해석하지 않는다.

## 현재 배포상 주의점

- 기본 앱 경로는 `<Assetto Corsa>/apps/lua/realvisor/`이고 진입 파일은 `realvisor.lua`다.
- **`docs` 전체가 참고 문서는 아니다.** `docs/runtime`, `docs/prototypes`,
  `docs/probes` 일부는 실제 실행 코드다. 현재 설치에서는 이 세 트리를 함께 제공한다.
- 기본 KN5는 Git의 `visors/` 분할 RAR에서 압축 해제한다. `.kn5` 자체는
  `.gitignore` 대상이다. Git clone만으로 압축 해제가 끝나는 것은 아니다.
- `Release/`는 현재 소스와 동등하다고 보장하는 배포 산출물이 아니다.
- P0 연속 물리 RainFX는 기본 OFF인 개발 프리뷰다. 보간·고임 반환은 연결됐지만
  수막의 외관·국소 합체·실제 전체 성능은 완료 판정이 아니다.
- `lights-patch-*`, 외부 셰이더 소스, 대형 영상과 실험 산출물은 앱 설치 필수가 아니다.
  저장소의 MIT 라이선스가 외부 CSP 바이너리·제3자 자산 재배포 권리를 대신하지 않는다.

## 설치 파일의 빠른 읽기 전용 점검

Python이 있는 개발/관리 PC에서 저장소 루트 기준:

```powershell
python docs/tools/check_installation.py --check-hashes
python docs/tools/check_installation.py --root 'D:/Games/Assetto Corsa/apps/lua/realvisor' --check-hashes
```

이 검사는 핵심 파일과 현재 물리 자산 manifest를 점검한다. 모든 동적 의존성의
최소 패키지를 증명하거나, 게임 동작·화면 품질·FPS를 보증하는 검사는 아니다.

## 프로젝트 방향

물리 크기·체적·질량과 표현용 배율을 분리한다. 실제 엔진 입력에 따라 약한 비의
고착 방울, 부분 젖음·마름, 강한 공급의 이동·트레일·수막이 구분되는 장면을 목표로 한다.
수치 검사 통과와 화면 품질 통과는 별도다. VRAM 점유보다 실제 실행 비용과 품질을
중시하며, 새로운 연구·사용자 시험은 [효율 정책](docs/RAINFX_DEVELOPMENT_EFFICIENCY.md)에
따라 범위를 제한한다.

라이선스: [LICENSE](LICENSE).
