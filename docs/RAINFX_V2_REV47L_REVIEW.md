# RainFX v2 — rev47l 리뷰와 rev48-S1 (2026-10-29)

## 1. rev47l 리뷰 요약
- FXC 12개 OK. field/trail에 X3571 경고(pow 음수 밑) 1건이 있었다. `pow(max(ca, 1e-12), ·)`로 수정했다.
- trail: Heavy와 Light 모두 크게 개선됐다. Light Rain 일부 방울의 짧은 trail이 아주 좋다(사용자).
- 기록: `docs/videos/rev47l_GAME_REVIEW/`(0 km/h와 sprint, Heavy와 Light, debug0, CSV)

| 기록 | 방울 수 | p50 r mm | 구간 비 | 서 있는 물 μm | 머무름 s |
|---|---|---|---|---|---|
| 정지 Heavy 30 s | 4 035 | 0.22 | 0.74 | 18.7 | 1.12 |
| 정지 Light 30 s | 1 406 | 0.14 | 0.44–0.65 | 2.2 | 1.57 |
| sprint Heavy 295 km/h | 13 125 | 0.12 | 0.68 | 45.4 | 0.20 |
| sprint Light 296 km/h | 12 915 | 0.10 | 0.50 | 10.9 | 0.58 |

- 정지 상태 머무름 시간이 처음으로 목표 범위(1–5 s)에 들어왔다. 고속은 0.2 s로 아직 짧다.
- 정지 30 s 안에 가장 큰 방울(≥ 1 mm)을 찾기 어렵다. 정지 Heavy의 서 있는 물은 18.7 μm로 아직 커지는 중이다. 큰 방울은 더 긴 시간이 지나야 생긴다. S3의 합체 형상과 함께 60–120 s 기록으로 다시 본다.

## 2. 바람 방향별 노출(Debug 2)이 변하지 않음
- 노출은 상대 빗방울 방향 = 낙하 + (바람 − 차 속도)로 계산한다. 정지 상태에서 150 km/h 바람이면 비가 수평에 가깝게 오므로, 바람 방향에 따라 바이저 노출이 크게 바뀌어야 한다.
- 이번 기록 CSV는 모두 windKmh 0이라 바람 시험 데이터가 없다.
- 가장 유력한 원인: 바람 벡터를 `sim.windVelocityKmh`(게임 공간 vec2)에서만 읽었다. 날씨 앱이 풍속(windSpeedKmh)만 바꾸고 이 벡터가 0으로 남으면 바람이 적용되지 않는다.
- **수정:**
  - windVelocityKmh가 풍속의 20 % 미만이면 `windDirectionDeg`(실세계 방위)와 트랙 방위(`ac.getCompassAngle`)로 바람 벡터를 만든다.
  - 기본은 기상 관례("불어오는 방향")다. 반대일 경우를 위해 체크박스를 둔다.
  - Physics 패널에 바람 출처와 상대 빗방울 방향(수직에서의 각)을 표시한다.
- 확인 요청: 150 km/h 바람에서 패널의 `from ...`과 `deg from vertical` 값(정지 상태에서 약 80°가 나와야 함), Debug 2 색 변화.

## 3. rev48-S1 형상 상태
`docs/RAINFX_V2_SHAPE_STATE_PLAN.md` §7을 본다.

## 4. S1 리뷰 (2026-10-29)
- FXC 12개 OK.
- 형상 클래스를 모두 확인했다. 정지 상태에서 서서히 원형으로 복원되는 것도 확인했다. 기록: `docs/videos/rev47l_shape_tensor_GAME_PREVIEW/`.
- **바람 노출:** 라이브 세션에서는 바람 방향에 따라 노출이 바뀐다. **리플레이에서 날씨 컨트롤러가 덮어쓴 바람에는 반응하지 않는다**(사용자 교차 검증).
  - 원인: `sim.windVelocityKmh`와 `windSpeedKmh`는 리플레이에서 기록된 바람을 유지한다. 컨트롤러의 덮어쓰기(`ac.overrideReplayConditions`)는 조건 세트(`sim.weatherConditions.wind`: 방위 각도, km/h)에만 반영된다.
  - **수정(rev48-S1b):**
    1. 리플레이(`sim.isReplayActive`)에서는 `weatherConditions.wind`를 쓴다. 풍속은 speedFrom과 speedTo의 평균이다.
    2. 방위에서 게임 공간으로 바꿀 때는 `ac.getCompassAngle`로 트랙 방향과 좌우 손잡이를 구한다.
    3. "불어오는/불어가는" 관례 오프셋은 라이브 세션에서 windDirectionDeg와 실제 게임 공간 벡터를 비교해 **자동 보정**하고 저장한다. 기본값은 180°(기상 관례)다. 패널에 180° 뒤집기 버튼이 있다.
  - 검산: `docs/tools/rainfx2_mock/wind_source_test.lua`. 트랙 방위 30°, 36 km/h 바람으로 라이브에서 보정(오프셋 180°)하면, 리플레이 조건 세트에서 같은 바람 벡터가 재현된다.
