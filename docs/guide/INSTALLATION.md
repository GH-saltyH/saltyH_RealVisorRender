# 설치·업데이트

2026-10-25 정리 이후에는 보존된 `docs/runtime/prototypes/probes` 트리와
`runtime_dependencies.json` 목록을 기준으로 설치한다. 과거 독립 probe 앱은 설치하지 않는다.
복구용 `archive/`는 앱 실행 필수가 아니며 Git에서 제외했다. 새 구현안은 아직 미구현이다.

[처음으로](../../README.md) · [운용](OPERATIONS.md) · [유지보수](MAINTENANCE.md)

## 필요한 환경과 확인 범위

- Windows의 Assetto Corsa와 CSP Lua 앱 환경이 필요하다.
- 최근 실제 엔진 조사·실행 기준은 **CSP0.3.0-preview728**이다.
  이전649와의 비교는 [CSP 대응 기록](../RAINFX_S276_CSP728_AND_ZERO_DEBIT.md)에 있다.
  소스 머리말의477+/542 표기는 과거 기준이며 새 물리 경로의 최소 버전 보증이 아니다.
- 다른 CSP 버전·VR·특정 업스케일러 조합의 전체 검증표는 없다. 버전을 기록하고 평가한다.
- Python·Blender·Visual Studio는 개발/자산 생성용이며 앱을 게임에서 실행하는 필수 설치는 아니다.
- 비를 시험하려면 WeatherFX/날씨 공급자가 실제 강수 값을 보내는 세션을 사용한다.
  Pure는 가능한 공급자 중 하나이며 이 코드의 필수 별도 의존성으로 규정하지 않는다.

## 앱 폴더

파일을 아래처럼 배치한다. `realvisor/realvisor/realvisor.lua`로 이중 중첩하지 않는다.

```text
<Assetto Corsa>/apps/lua/realvisor/
  manifest.ini                 앱 등록
  realvisor.lua                메인 진입점
  icon.png
  *.lua                        함께 제공된 루트 Lua 모듈
  settings.ini                 위치·프로필 설정
  settings_mats.ini            재질 설정
  shaders/
  texture/
  visors/
    visor_lando_2025Champion_maxquality_diet_face.kn5
  docs/
    runtime/                   현재 제품 코드 포함
    prototypes/                현재 코드가 가져오는 모듈 포함
    probes/                    실제 입력 어댑터 등 포함
```

현재는 이 트리의 최소 의존성만 골라내는 정식 패키저가 없다. **루트 앱 파일,
shaders, texture, visors와 docs의 위 세 코드 트리를 같은 소스 스냅샷으로 복사한다.**
`docs/diagnostics`, `docs/videos`, `docs/images`, `docs/tools`와 Markdown은 일반
게임 실행에 필수인 전체 폴더로 규정하지 않는다. 단, 유지보수·개발 인계에는 보관한다.
`docs/probes`를 복사하는 것과 독립 진단 앱을 별도로 설치·활성화하는 것은 다르다.

## KN5 압축 해제

Git에는 다음 분할 RAR가 제공된다. `.gitignore`는 `.kn5`를 제외한다.

```text
visors/extract_here_visor_lando_2025Champion_maxquality_diet_face.part1.rar
visors/extract_here_visor_lando_2025Champion_maxquality_diet_face.part2.rar
visors/extract_here_visor_lando_2025Champion_maxquality_diet_face.part3.rar
```

세 파일을 같은 폴더에 두고, 분할 RAR를 지원하는 도구에서 **part1만 시작점으로**
압축 해제한다. 최종 KN5를 위 경로에 둔다. 파일 확장자를 RAR→KN5로 바꾸면 안 된다.
현재 자산 manifest가 기대하는 모델 SHA-256은 다음과 같다.

```text
2596f63e20a02bc0608bfc11270f892d500f45b499a1b2331045b361d83031b9
```

모델을 바꾸면 자산도 함께 재생성·검증해야 한다. 다른 KN5를 같은 이름으로 바꾸는
것만으로 호환되지 않는다. 파일 크기 표시에 의심이 있으면 실제 읽기 기반 hash 검사로 확인한다.

## 새 설치 순서

1. 게임을 종료하고 설치할 소스의 커밋·파일 묶음을 정한다.
2. 모델을 압축 해제하고 앱 트리를 복사한다. 기존 설치가 있으면 먼저 백업한다.
3. 앱 파일을 게임에서 읽을 수 있고 설정·진단 위치에 쓸 수 있는지 확인한다.
4. Content Manager를 쓰는 경우 Lua 앱 목록에서 `Real Visor Overlay`를 활성화하고
   게임 세션의 앱 목록에서 연다. 목록이 갱신되지 않으면 세션/관리 프로그램을 재시작한다.
5. 우선 일반 바이저 출력·Transform 위치·KN5 가시성을 확인한다. P0는 처음부터 자동 ON이 아니다.
6. [운용 절차](OPERATIONS.md)에 따라 필요할 때만 P0를 시작한다. 다른 단계 진단은 OFF로 둔다.

## 업데이트와 되돌리기

- 앱 디렉터리, `settings.ini`, `settings_mats.ini` 및 CSP가 관리하는 script settings를
  백업한다. 설정을 읽어오는 방식은 [유지보수](MAINTENANCE.md)를 따른다.
- Lua만 최신이고 `docs/runtime`·prototypes·셰이더·자산은 옛 버전인 혼합 설치를 피한다.
- 설정 파일을 무조건 새 기본값으로 덮어쓰지 않는다. 새 기본값을 따로 보관하고 차이를 검토한다.
- Lua 변경은 앱 reload로 적용할 수 있다. 모델/자산 변경·서로 다른 probe 자원 정리는 새 세션이 낫다.
- 문제 시 소스·셰이더·자산을 **동일 백업 묶음**으로 되돌린다. 데이터는 따로 보존한다.
- `Release/`와 옛 `install_s*.ps1`을 최신 전체 설치본/통합 업데이트 도구라고 가정하지 않는다.
  옛 스크립트는 특정 단계와 개발자 경로에 묶여 있다.

## 현재 개발 PC의 연결 설치와 일반 설치의 차이

현재 개발 환경은 게임 앱의 `docs`와 `shaders`를 작업 폴더로 연결해 사용한다.
따라서 해당 소스 수정이 설치본에도 즉시 반영될 수 있다. 이것은 이 환경의 배치 방식이며
일반 사용자가 심볼릭 링크를 만들어야 하는 요구사항은 아니다. 일반 설치는 실제 파일 복사로 가능하다.
백업/삭제 전에 링크 대상을 확인한다. 링크된 앱에서의 수정은 저장소 원본 수정일 수 있다.

## 선택적 cockpit-camera 동반 스크립트

`put this extension-lua-cockpit-camera/RealVisorCameras/`는 별도의 CSP cockpit-camera
동반 스크립트다. 메인 앱의 필수 실행 의존성과 구분한다. 사용할 경우 CSP의 cockpit-camera
스크립트 위치(`<Assetto Corsa>/extension/lua/cockpit-camera/`) 아래에
`RealVisorCameras/` 구조로 배치하고 해당 스크립트를 선택한다. 기존 카메라 설정을 먼저 백업한다.
이 동반 스크립트의 전체 버전별 UI 동작은 이번 문서 점검에서 재시험하지 않았다.

## 설치 읽기 전용 점검

저장소 루트에서:

```powershell
python docs/tools/check_installation.py --check-hashes
python docs/tools/check_installation.py --root 'D:/Games/Assetto Corsa/apps/lua/realvisor' --check-hashes
```

`passed`, `missingOrEmpty`, `hashMismatches`를 확인한다. 모델과 현재 s152 manifest의
자산·입력 모듈을 점검하지만, 모든 동적 경로·CSP API·화면 품질을 증명하지는 않는다.
실패했다고 manifest의 hash를 현재 값으로 바꿔 통과시키지 않는다. 누락·혼합 설치인지,
의도적인 자산 갱신인지 먼저 판별한다.
