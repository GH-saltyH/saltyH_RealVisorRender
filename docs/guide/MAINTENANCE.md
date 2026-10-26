# 유지보수·백업·자산 변경·인계

## 테스트 도구 정리 이후

원본 실험 도구·소스/작은 보고서와 정리 전 안내서는
`archive/2026-10-25_legacy_research.zip`에, 게임에 설치됐던13개 probe는
`archive/2026-10-25_installed_probe_apps.zip`에 보관했다. 두 파일은 Git 제외다.
별도 백업 없이는 커밋만으로 이 보관본이 전달되지 않는다.

`docs/development/cleanup_20261025/report.json`과 `plan.json`은 정리 범위·용량·hash를
기록한다. 대형 재생성 가능 dump/컴파일 출력은 삭제됐고 모두 복구되는 것은 아니다.
현재 자동 실패 보고서/frozen 재고와 목표 영상 표본은 남겼다. 복원할 때는 ZIP을
별도 폴더에 먼저 풀고 필요한 항목만 확인해 옮긴다. 구형 도구 전체를 앱에 덮어쓰지 않는다.

현재 실행 의존성은73개 Lua manifest로 관리한다. 활성 개발 검사는 기본 설치·구문
점검으로 축소했다. 아래 옛 상세 도구 경로가 없으면 보관본의 동일 상대 경로를 확인한다.

[설치](INSTALLATION.md) · [운용](OPERATIONS.md) · [개발](DEVELOPMENT.md)

## 설정과 실행 결과를 분리해서 보관

| 자료 | 보관 이유 |
| --- | --- |
| 소스 커밋과 실제 설치 파일 묶음 | manifest의0.6.0만으로는 단계·동작을 식별할 수 없음 |
| `settings.ini` | Transform 프로필, 활성 프로필/앱, 메시 가시성 등의 직접 저장 |
| `settings_mats.ini` | native/custom 재질 및 일부 runtime 편집 값 |
| CSP script settings | `ac.INIConfig.scriptSettings():mapConfig`로 관리되는 설정. 위 두 INI만으로 전체 설정이라고 가정하지 않음 |
| KN5·texture·shader·manifest | 모델과 bake가 맞는 일관된 자산 묶음 |
| 실패 report+동일 frozen request/DDS | 원장과 실물 재고를 함께 해석해야 함 |
| 측정 조건·영상·실험 판정 | 기능/외관/비용 회귀 비교 근거 |

CSP script settings의 실제 파일 위치는 관리 환경에 따라 확인한다. 문서에서 검증하지
않은 고정 경로를 가정해 일괄 삭제하지 않는다. 앱/게임이 쓰고 있는 동안 INI를 직접
편집하면 저장 시 덮일 수 있으므로 종료·백업 후 변경한다.

## 복구 순서

1. 실패 자료를 먼저 별도 폴더로 복사한다. 새 실행이 같은 보고서 경로를 덮을 수 있다.
2. 일치하는 이전 소스·셰이더·자산 묶음을 복원한다. 설정은 별도 백업과 비교한다.
3. 실제 게임 앱이 복원한 파일을 읽는지 확인한다. 작업 폴더 링크/별도 복사본을 혼동하지 않는다.
4. 읽기 전용 설치/hash 점검 후 일반 바이저→P0 순으로 범위를 좁혀 확인한다.
5. GPU 자원·모델·서로 다른 diagnostic 실행이 섞였으면 새 게임 세션으로 비교한다.

`fault/overloaded`를 단순히 꺼서 무시하거나 큐만 늘리지 않는다. 오류 파일·현재 재고·
입력 시간·처리 비용을 분리한다. 누수 판단은 GC 전 최고값보다 GC 후 최저값의 추세와
세션 자원 보유 정책을 함께 본다.

## KN5·UV·mask·교정 변경

모델의 메시 이름·UV·배율·mask가 바뀌면 렌더링만의 변경이 아니다. 면적·법선·
접선·입사 site·광학 매핑·field coverage·hash 계약이 영향을 받는다.

관련 생성 도구는 다음과 같지만, **아래는 의존성 지도이지 검증된 일괄 실행 레시피가 아니다.**
일부 도구는 특정 단계 산출물·경로를 전제로 즉시 파일을 덮어쓴다. 처음에는 복사본에서 실행한다.

| 변경/산출물 | 관련 도구·계약 |
| --- | --- |
| 유리/visor 광학 자산 | `docs/tools/build_visor_optics_assets.py` 및 `texture/GLASS` manifests |
| UV 표면 Jacobian 등 | `docs/tools/bake_rain_surface.py` — Blender background,2048×512 |
| DSD·impact 추정 LUT·birth sites | `docs/tools/build_s79_birth_assets.py` —128bin DSD 등 |
| field 면적·coverage·coat | `docs/tools/build_s81_film_cells.py` —1024×256 |
| 시작 시 검증 manifest | `docs/prototypes/s152/s152_assets.lua`와 관련 surface/spawn/atlas verify |

모델·mask→geometry/광학→birth/field→manifest 순의 영향을 확인하고 실제 도구 구현을
읽어 누락 산출물을 찾는다. 오래된 문서의 모델 이름·크기·shape를 그대로 믿지 않는다.
manifest의 hash만 새 값으로 덮는 것은 자산 재생성·기하 정합성 검증의 대체가 아니다.
현재 일반 표시 기준6px/mm@4096×1024와 mm³/SI 계산을 함께 재점검한다.

## 폴더 정리와 배포

- `docs/runtime`, `docs/prototypes`, `docs/probes`: 현재는 통째 보존·배포한다.
  삭제할 때는 실제 동적 load/preload와 UI fallback까지 의존성 분석이 필요하다.
- `docs/diagnostics`: 실행 코드와 구분해 보관/아카이브 가능하다. 재현 도구가 참조하는
  frozen 캡처·컴파일 prelude·source freeze를 없애면 해당 검사는 재현되지 않는다.
- `docs/videos`와 외부 `E:/...` 영상: 원본 증거의 위치일 뿐 일반 앱의 의존성이 아니다.
  다른 PC 인계 시 링크만으로 파일이 전달되지 않는다.
- `Release`, `tmp`, SDK ZIP 해제본, 외부 셰이더 저장소: 설치 필수로 복사하지 않는다.
  현재 일관된 배포본이라는 근거가 있는 산출물만 별도로 배포한다.
- Git에 무시된 KN5, Release, 영상 등은 커밋만으로 백업되지 않는다. 별도 자산 백업 필요.
- 링크가 걸린 디렉터리는 삭제 전에 실제 대상을 확인한다. 게임 폴더의 정리가 원본
  작업 트리 삭제가 되지 않도록 한다.

## 새 개발자에게 넘길 최소 묶음

현재 소스 커밋+미커밋 diff, 모델 분할 RAR/해제 KN5와 hash, texture/shader/verify,
이 guide 전체, 현재 상태/로드맵, work ledger, 최신 실패/성공 증거, Windows 도구 경로와
현재 CSP 버전·시험 조건을 함께 제공한다. 외부 자산/SDK의 권한은 별도로 확인한다.

다음 공백도 함께 알린다: 정식 최소 패키저·의존성 lockfile·범용 CI·완전 자동 bake
파이프라인은 아직 없다. 새 환경 설치 점검과 실제 엔진 smoke test를 인계 완료 조건에 둔다.
