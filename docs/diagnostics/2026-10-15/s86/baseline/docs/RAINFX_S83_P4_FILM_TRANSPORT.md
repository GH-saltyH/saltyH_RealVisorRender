# RainFX s83 — P4a 보존적 film 수송·배수 프리뷰

Date: 2026-10-15. Status: REFERENCE — 기본 OFF인 첫 수송 프리뷰. s84에서 제공된 원장/FPS 검토 완료; 큰 Courant로 시간 정확도 gate 미통과, 진단 확장 및 다음 모델 검토 중.

## 1. 기준과 범위

s82의 제공된60% 물 원장과3분/40회 메모리 관찰을 확인한 뒤 진행했다.
사용자 P2 stamp `1ad4a95f48d7b683f38b9134bf6c202eb363780e` 이후 작업이며,
브랜치 `codex/rainfx-physics-weather`를 유지한다. 커밋/push는 사용자가 한다.
이번 전 기존 P1/P2/P3 숫자·bool tuning은 유지했다.

**P4a 범위:** 현재 film 체적의 중력·차량 관성·상대풍 전단에 의한 이동,
지원 경계 밖 배수, 원장 보존과 Courant 제한 진단.
P3의 입사/같은 프레임 head→trail/증발과 함께 공동 publish한다.
새 render mesh, 별도 scene copy, Smear, legacy local impact film은 없다.

**이번에 제외:** head 재흡수, 실제 child 생성, 곡선 midpoint 분할,
film의 모세관 압력/곡률·접촉선 hysteresis, micro 개별 입자 이동.
s73의 재흡수는 cell별 총요청 배분과 paired commit이 필요한 별도 비용 gate다.
이번에 여러 head가 같은 field 물을 각자 가져가는 근사를 넣지 않았다.

## 2. 축소 물리 모델

실제 셀 면적과 현재 film 재고에서 `h_m = V_mm3 / area_mm2 * .001`.
국소 Newtonian film의 no-slip 벽, 표면 전단 `tau`에서 준정상 Stokes 식을
두 번 적분한 평균 속도 근사를 사용한다:

```text
mu * u'' = -rhoWater * accelerationTangent
u(0) = 0; mu*u'(h) = tau
meanVelocity = rhoWater*h^2/(3*mu) * accelerationTangent + h/(2*mu) * tau
tau = .5 * rhoAir * Cf * |airTangent| * airTangent
```

얇은 film의 중력/전단 모델에 대한 근거는
[Gaskell 등의 gravity-driven thin film 연구](https://eprints.whiterose.ac.uk/1203/01/gaskellph5.pdf),
[표면 전단을 포함한 film 실험 연구](https://pmc.ncbi.nlm.nih.gov/articles/PMC10689780/)다.
우리 식은 실제 바이저 교정값이 아닌 축소 모델이다. 두꺼운 고임, 큰 slope,
고 Reynolds, 급격한 접촉선 변화에서 이 가정의 정확도를 보장하지 않는다.
물의 rho998.2kg/m³와 mu.001002Pa·s는 기존20°C 참조값을 유지한다.
새 `RAIN_FILM_FLOW_CF=.005`는 **미측정 local air skin-friction 시작값**이다.
공기 방울의 attached Cd와 동일한 계수로 취급하지 않는다.

P1이 실제 사용한 transform, force bit mask, verified 관성, air world vector,
local-air fraction, wind 포함 옵션과 downward override를 그대로 전달받는다.
중력은 P1과 같은 world−Y9.80665m/s²이며 차량 G에서 다시 더하지 않는다.
바이저의 실제 Jacobian을 world로 회전/scale해 tangent와 UV 속도를 만든다.
G-force 카메라 이동 또는 임의 UV의 위/아래를 중력으로 사용하지 않는다.

coating은 기존 deposition/micro joining에 계속 반영된다. 첫 수송에서 coating
별 별도 slip/contact-line 법칙은 추가하지 않았다. unresolved micro는 이동하지 않고,
P3의 joining으로 film이 된 물부터 수송한다.
물리 D·질량·표시 gain/광학 gain/old texel radius는 수송 속도 입력에 없다.

## 3. 보존적 이웃 전달과 제한

직전 성공 field를 donor로 읽어 각 셀의4방향 outgoing film 체적을 계산한다.
X/Y 각각 최대 한 방향이며 전달량은 양수다.

```text
travelInCells = projectWorldVelocityToUV(meanVelocity) * gridSize * sim.dt
Courant = abs(travel.x) + abs(travel.y)
share = abs(travel) * min(1, .8 / Courant)
```

큰 dt에서도 물을 음수로 만들지 않도록 총 outgoing 비율을.8 이하로 제한한다.
X 실제 float32 차감→Y 실제 차감 순서로 구한 양을 flux에 저장하고,
gather에서 같은 순서로 빼고 이웃의 **저장된 같은 양**을 더한다.
recipient 면적이0인 halo/구멍에서는 P3의 누적 runoff에 넣는다.
partial supported cell은 그 지원 면적을 가진 유한 체적 셀로 취급한다.
이미 전달한 물에 source kernel coverage를 다시 곱하지 않는다.

수송은 이전 field만 움직인다. 그 프레임의 birth/trail은 기존 sparse resolve에서
추가되므로 수송에는 다음 step부터 참여한다. deposit segment를 격프레임으로
건너뛰거나 CPU 리드백/스탬프로 되돌리지 않는다.
정규화되지 않은 backward texture advection도 사용하지 않는다.

이것은1차 donor/upwind 공간 근사라 수치 확산이 있다. 격자보다 작은 곡선이나
물리적 capillary smoothing을 해결했다고 주장하지 않는다.

### Courant 제한의 의미

`sim.dt`는 잘라 버리지 않지만 raw Courant>.8이면 속도가 수치적으로 느려진다.
이 영역은 프레임레이트 의존성이 있으며 실제 물리 시간 정확도 통과가 아니다.
예를 들어 중력에 평행한200µm film의 이 식상 평균 속도는 약.13m/s로,
미세 격자에서 제한에 걸리기 쉽다. 이를 임의 속도 gain으로 감추지 않는다.
전 셀 substep을 무조건 추가하는 것은 비용을 배수로 키우므로 이번 프리뷰에서 제외했다.
게임의 limited cell/volume 비중을 보고 substep/격자/수송 대안의 비용을 결정한다.

`Log P4 transport limiter`는 버튼을 누를 때 현재 published field에서
현 파라미터/dt의 raw Courant를 재평가한다:

- `maxCourant`: 최대 raw Courant;
- `limitedCells`, `wetCells`: .8 제한을 넘는 셀/film이 있는 셀 수;
- `limitedFilmMM3`: 제한 대상 셀에 현재 있는 film 재고 합;
- `limit=.8`, `dt`: 제한 기준과 평가 시간 간격.

이는 **현재 field의 제한 추정**이며 마지막 적용 pass의 속도 손실 적분이나
limitedFilmMM3만큼의 물을 삭제했다는 로그가 아니다.
shader pending이면 published field와 현 시도 파라미터의 프레임이 다를 수도 있다.
물 원장 버튼의 prefix는 기존 `Rain P3`를 유지하고 suffix `transport=P3/P4`로 구분한다.

## 4. 비용·자원·준비 gate

기본 OFF: `RAIN_PHYSICS_P4_TRANSPORT_PREVIEW=false`.
P1/P2/P3를 켠 상태의 P0 패널 안에서 P4 체크박스로 시험한다.
토글은 기존 물/state/source epoch를 reset해 모드 간 과거 재고를 섞지 않는다.

- **steady 추가:** inner1024×256 RGBA32F flux 하나 = **4,194,304bytes (4.00MiB)**.
- **추가 pass:** flux1개/성공 물리 step. 이웃 gather는 기존 P3 resolve에 통합했다.
- 빈 halo는 flux를 저장하지 않는다. field halo는 기존 것을 그대로 써 배수를 받는다.
- resolve는 대상1개와 이웃4개의 flux를 읽는다. 별도 CPU 방울 루프가 없다.
- P4 limiter 수동 진단은66×18/5×2 RGBA32F와4×1 R32, 총19,184bytes를
  최초 버튼 요청에만 배정한다. 매 프레임 전체 합산이나 readback은 없다.
- steady canvas는 재사용하고 reset 때 texture 참조·pending callback epoch를 비운다.
- flux 준비 실패도 state/meta/field/optics/source/clock 공동 게시를 막는다.
  부분적으로 새 bank를 표시하거나 같은 사건을 두 번 더하지 않는다.

정확한 GPU ms/FPS 비용은 아직 측정하지 않았다. 읽기·연산이 추가되므로 저비용
확정 또는 성능 전체 통과로 기록하지 않는다. full CFD/SPH나 unverified MRT/UAV API를 전제하지 않는다.

### 표면 이웃 조건

4-neighbour stencil은 물리적으로 이어지는 supported UV를 전제로 한다.
offline film builder에서 position/du/dv로 이웃 chord와 local metric을 비교한다.
현재 모델은 discontinuous edge0, degenerate supported cell0으로 `flowConnectedUV=true`다.
cell DDS 자체/면적/단위/geometry model·mask SHA는 그대로다.
현재 연결 검사(최대4배 local step 또는2mm tolerance)는 보수적인 seam 탐지 근사이며
정확한 mesh face topology 증명은 아니다. 새 KN5의 불연속 UV는 P3를 허용하되
P4를 켤 수 없게 한다. 그 경우 별도 face link bake부터 필요하다.
이 검사는 offline build에서만 하므로 앱 로딩 시 전체 position atlas를 새로 읽지 않는다.

## 5. 수치 정밀도

수동 `rainFilmBlocks`의 fine/coarse 및 `rainFilmTotals` 합산에 Kahan 보상을 적용했다.
추가 steady texture/pass나 물리 재고 보정은 없다.
불균일 field 시험에서 double 합 대비 최대 오차가 .00226534→.000130034mm³로 감소했다.
작은 손실을 evaporation으로 바꾸거나 residual만큼 물을 생성하지 않는다.

**s82의 persistent field 누적 반올림 문제 전체를 해결한 것은 아니다.**
현재 필드 안의 source add/join/evaporation/loss 채널은 여전히 float32다.
P4의 수송도 float 덧셈을 추가한다. 장시간 sparse 공급·건조·배수 게임 원장 gate가 필요하다.
full compensation bank의 추가9.281MiB와 대역폭을 바로 넣지 않고, 실제 수송의
보존 오차·CFL·비용을 먼저 분리해 평가한다.

## 6. 검증

`diagnostics/2026-10-15/s83/`:

- `check_s83_flow_gpu.py`: actual FXC ps_5_0 /Ges /WX + D3D11 WARP9개 검사.
  중력 방향/관성 반전/normal force 제외/h² scaling/전단/downward override,
  .8 제한/양수 재고/halo·구멍 runoff, 수동 MAX/SUM 진단과 합산 정밀도.
  20단계 수송 stock+loss 원장 residual 약−4.67e-9mm³.
  **P4 OFF field 결과는 전달된 s81과 bit-identical**(진단 합산만 별도 개선).
- `check_s83_flow_binding.py`: 실제 Lua factory/main prepare/reset/publish를 실행하고
  CSP canvas를 mock. P1 transform/force flags, flux pending 시 read bank/clock 유지,
  수동 진단, stale callback dispose, P3/P4 40회 토글 및 reset live bank0 검사.
  기존 P3 Lua12개 검사도 통과했다. 실제 SDK/driver 비용·메모리 시험은 아니다.
- 기존 P3 GPU13개 field/descriptor/source/evap/wet impact 검사를
  `p3_regression/`에 재실행했다. 렌더 셰이더·P2 birth/motion 코드의 변경은 없다.

모든 기존 숫자/bool 설정 보존, cell DDS 불변 및 설치된 모듈/새 shader SHA를
전달 기록으로 대조한다. Git commit/push는 하지 않는다.

## 7. 게임 검증

앱 reload 후 P0 패널에서 P1/P2/P3와
**Enable P4 conservative transport preview (resets water)**를 켠다.

1. 이전 낮60% 조건에서 정차와100–150km/h 직진을 관찰한다.
   같은 경과 시간의 P3-only와 P4를 비교한다(토글은 재고 reset).
2. 각 조건의0/15/30초에 `Log P3 actual water budget`과
   `Log P4 transport limiter`를 함께 기록한다.
3. 정상 optics와 P3 view1(film µm)에서 수막이 이동하고 지원 경계에서 빠지는지,
   새로운 격자 떨림/역방향 흐름/급격한 끊김이 생기는지 관찰한다.
4. 동일 리플레이/장면/경과 시간에서 P3-only와 P4 FPS/Memory를 비교한다.
   compile 준비 구간과 warm 구간은 분리한다. 가능하면30/60FPS에서 제한 양상도 비교한다.

초기 gate는 보존·제한 비중·비용이다. 고속 flow 시간 정확도나 재흡수·전체 P4 완료로
판정하지 않는다. 이 gate 이후 추가 transport 비용이나 재흡수 구현을 결정한다.
