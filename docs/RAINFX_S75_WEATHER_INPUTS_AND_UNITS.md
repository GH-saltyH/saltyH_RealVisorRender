# RainFX s75 — P0 날씨 입력·단위·metric 진단 구현

Date: 2026-10-14. Status: ACTIVE — P0 코드·검증·설치 완료. 사용자 실측으로 G convention 확인; 국소 바람/metric 추가 교정은 후속 검증.

## 시작 기준과 이번 범위

사용자가 게시한 `397549102c3e5488b88b794924a75e39178a28e8`에서
`codex/rainfx-physics-weather` 브랜치로 진행했다. 시작 시 작업 트리는
깨끗했고, runtime/shader/settings/docs를 s75 baseline에 보존했다.

설계의 첫 단계 P0를 구현했다. 새 입력을 먼저 관찰·검증하며 기존
렌더러/운동/출현/Smear/local impact film 경로에는 아직 전달하지 않는다.
따라서 이번 스탬프에서 새 물리 모델의 화면 변화를 기대하는 단계는 아니다.
설계 P1에서 사용할 물리 단위·접촉 형상 함수도 독립 모듈로 준비했다.

## 1. 독립 입력 어댑터

`rain_environment.lua`는 constructor에서 하나의 상태를 만들고 같은
`sim.frame`에는 한 번만 갱신한다. Smear의 wind/facing/density나 GPU
readback을 이용하지 않는다. 외부 상태에 쓰지 않고 배경 로그를 생성하지 않는다.

입력 계약:

- rain intensity/wetness/water는 live sim scalar를 우선하고, 결측/NaN/
  무한대이면 `sim.weatherConditions`의 동일 값을 fallback으로 읽는다.
- 유효한 **0**은 유지한다. rain override 0도 명시적인 테스트 입력이다.
- 트랙 물 값은 별도 스칼라로 보관하며 바이저 물 재고나 공급으로 전환하지 않는다.
- humidity/pressure는 filtered conditions를 읽는다. 결측 시
  `ac.getAirHumidity(position)`, `ac.getAirPressure(position)`를 선택적으로
  호출하며 최대 5 Hz로 제한한다. 압력 API의 kPa는 Pa로 변환한다.
- 범위 밖 값은 진단용 범위로 제한하되 valid flag를 false로 둔다.
  fallback RH=.5/T=20°C/p=101325 Pa는 **관측값이 아닌 명시적 fallback**이다.
- invalidMask/clampedMask를 표시한다. bit 1 I, 2 wetness, 4 water,
  8 temperature, 16 RH, 32 pressure. fallback source는 필드별로 표시한다.
- filtered `currentType/upcomingType/transition`으로 액체 비율을 보간한다.
  Snow/Sleet/Hail 7개 enum은 신규 액체 비율 0, unknown 타입은 유효한
  rain 채널을 보존한다. enum table 누락은 별도 표시한다.
- world wind는 SDK game-space vec2의 (x,z) km/h를 /3.6으로 변환한다.
  상대 공기는 wind-car velocity로 표시한다. 이전 Smear 축 옵션은 읽지 않는다.
- car acceleration은 car-local G 원본과 car basis를 사용한 world×g
  변환을 함께 표시한다. 이 값은 아직 중력 보정을 마친 관성 입력이 아니다.
- 정차(|v|<.15 m/s)에서 G 평균을 최대 256 표본 상태로 집계한다.
  그 평균을 근거로 중력을 자동 제거하거나 `physicsReady`를 켜지 않는다.
- angularVelocity는 원본만 관찰한다. 공개 선언의 단위 설명이 부족해
  rotation units를 unverified로 둔다.

기온/RH로 dew point를 계산하고 moist ideal-air density를 추정한다.
이는 바이저 온도 측정이나 응결 생성 기능이 아니다. RH=0의 dry limit은
유한 이슬점으로 꾸며내지 않는다. Magnus 근사 계수와 역산의 근거:
[Alduchov & Eskridge (1996)](https://journals.ametsoc.org/view/journals/apme/35/4/1520-0450_1996_035_0601_imfaos_2_0_co_2.xml).

## 2. SI/접촉 형상 준비

`rain_physics_units.lua`는 표시 배율/reference UV를 입력으로 받지 않는다.
다음의 순수 함수를 제공한다.

- equivalent D(mm) ↔ V(mm³), V→mass(kg).
- spherical-cap V↔contact radius(mm), θ 의존성.
- contact-line pinning(N), normal impact Weber number.
- baked Jacobian의 orthonormal plane에서 raw UV↔metres 변환.
- 국소 U/V px/mm와 물리 cell area(mm²) 산출.

20°C 물성의 진단 기준 rho=998.2 kg/m³, mu=.001002 Pa·s,
gamma=.0728 N/m를 사용한다. 온도별 LUT 및 재질 hysteresis/항력
교정은 P1 작업이다. helper가 준비되었다고 기존 물리 상태의 meta.G를
이미 실제 질량/부피로 바꾼 것은 아니다.

명목 6 px/mm와 실제 국소 metric을 비교할 수 있도록 기존 geometry의
중앙(.5,-.5) 표본을 표시한다. 이 점이 지원되지 않으면 바깥점이라는
메시지를 표시한다. Jacobian/모델 scale에서 산출한 물리 cell 면적은
화면/UV 텍셀 수와 분리된 값이다. visual/physical transform의 완전한
분리는 P1에 남아 있다.

## 3. 앱 연결과 UI

`realvisor.lua`에 lazy module loader hook을 연결했다. script.update에서
초기화/렌더 early return 전 관찰할 수 있다. 새 chunk-level local을
추가하지 않았으며 기존 GPU state/meta 프로그램과 설정은 유지했다.

**RainFX → Weather inputs and physical units (P0)** 패널:

- rain/phase/트랙 값, RH/T/p 및 source/fallback 표시.
- 바람·상대 공기, raw car G와 world×g, 정차 평균·표본 수.
- nominal 6 px/mm와 KN5 국소 metric, 1.15 mm의 부피·질량·접촉 직경 예제.
- `Reset stationary samples`: 정차 관측 평균만 초기화.
- `Log input snapshot`: 버튼을 누를 때만 콘솔에 snapshot 출력.

factory 또는 geometry 준비가 실패/대기 중이면 진단 패널에 이유를
표시한다. 기존 FX 출력은 이 모듈의 상태를 gate로 사용하지 않는다.

## 4. 설치와 검증

새 두 모듈은 게임 앱 폴더에 **해시 검증한 일반 파일**로 설치했다.
처음 시도한 symbolic link 생성은 관리자 권한을 요구했으므로 복사
방식으로 설치했다. 기존 realvisor.lua 링크는 유지한다.
`docs/tools/install_s75_inputs.ps1`은 matching link/current copy 또는
마지막 설치 해시와 일치하는 copy만 갱신한다. 별도 수정한 게임 파일을
덮어쓰지 않는다. `installed_modules.json`에 마지막 설치 해시를 기록한다.

검증 도구: `docs/tools/check_s75_inputs.py` 및 `s75_input_cases.lua`.

- 전체 realvisor.lua 및 두 모듈의 LuaJIT syntax 통과.
- 실제 lazy hook/UI callback 실행: 한번만 모듈 생성, once-per-frame 갱신,
  missing module/geometry 준비/지원 밖 metric, manual log 경로 통과.
- valid zero, nil/NaN/infinity/range, optional API 실패·cache,
  kPa/Pa, snow/sleet/hail 및 transition, unknown 타입 시험 통과.
- car basis 회전과 raw G 변환, 정차 bounded sample, auto promotion 없음.
- spherical-cap 역산 최대 오차 약 8.53e-14 mm³, metric round-trip 오차 0
  (테스트한 skew/scale 사례), 질량 D³·접촉각·pinning/We 단위 검산 통과.
- JIT warm-up 후 같은 call site의 40,000 observer 갱신에서 지속
  retained-memory 증가 없음. 진단 CPU fixture 결과이며 실제 CSP 비용
  또는 GPU frame time 측정으로 해석하지 않는다.
- P0 hook/UI 추가를 제거한 realvisor.lua가 baseline과 동일함을 검사한다.
  모든 shader, rain_surface/rain_trails, 설정 파일은 SHA 불변이다.
- game/workspace의 realvisor.lua 및 새 두 모듈의 SHA 일치 확인.

사용자 로그에서 CSP 상태 구조와 G convention을 관측했다. world wind
방향의 독립 확인·실물 KN5 metric 및 인게임 frame time은 후속 검증이다.
P0에서 GPU pass를 추가하지 않았지만, 실제 앱 CPU 비용은 별도 확인해야 한다.

## 5. 다음 단계의 입력 gate

사용자가 평지 정차·가속·제동 snapshot을 제공했다. 정차 raw G와 256개
정차 평균은 (0,0,0)이다. 가속 car Z=+.68933 G, 제동 Z=-3.27861 G로
fore/aft 부호도 일치한다. **관측한 G는 중력을 제외한 차량 가속도다.**
어댑터의 관성 벡터는 `-9.80665 × world(car G)`로 확정했다. 여기서
중력을 다시 빼지 않는다. P1에서는 별도 gravity와 합성한다.

| 상태 | raw car G | world inertia m/s² |
|---|---|---|
| 정차 | (0,0,0) | (0,0,0) |
| 가속 | (.02990,-.20954,.68933) | (5.70589,1.97306,-3.68181) |
| 제동 | (-2.06911,.12269,-3.27861) | (.45861,.68473,38.02966) |

I=.6/RH=.8/T=22°C/p=101325 Pa에서 invalid/capped=0, dew point≈18.3905°C,
추정 air density≈1.186541 kg/m³를 관측했다. 트랙 water=1은 바이저 공급량으로
대입하지 않는다. rotation units는 아직 unverified로 유지한다.

후속 P1 shared SI core를 작성해 D3D11 WARP 검증했다. 부피·접촉선·GPU
metric·중력/관성·항력·저항 함수가 준비되었고, persistent state/렌더 연결은
다음 구현 단계다. 자세한 내용은 `RAINFX_S76_SI_CORE_PRIMITIVES.md`를 참고한다.

## 산출물

- `docs/diagnostics/2026-10-14/s75/baseline_manifest.json`, `baseline/`.
- `checks.json`: 실행한 검증 및 installed-source equality.
- `source.diff`: 게시 커밋 기준 runtime hook/UI 변경.
- `installed_modules.json`: companion 모듈 설치 해시.
