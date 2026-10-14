# RainFX s79 — 물리 유입·가상 충돌의 GPU 연결

Date: 2026-10-14. Status: ACTIVE — opt-in P2 birth preview 구현 및 WARP/LuaJIT 검증 완료. 게임 입력 방향·룩·비용 검증 대기.

## 1. 기준과 범위

사용자의 `acc0c63` (`s78 passed P1 test`)에서 시작했다.
`codex/rainfx-physics-weather`에서 작업하며 commit/push는 사용자가 한다.
P1 및 레거시 비교는 P2 OFF로 유지한다. P2는 `RAIN_PHYSICS_P2_BIRTH_PREVIEW=false`가 기본이다.

이번 연결:

- s78 128-bin 대기 NUMBER DSD → GPU CDF sampling.
- 실제 KN5 metric 면적·outward normal·차량 상대풍 → 입사 공급.
- 체적 기준 충돌 분배와 초기 접선 impulse → 같은 프레임의 state/meta commit.
- film/micro/bounce/capacity/exit/drop inventory의 GPU 원장.

**아직 최종 RainFX/P2 전체 완료를 뜻하지 않는다.** film/micro는 공간장에 놓이지 않은
누적 reserve이며, P3의 실제 수막·미세 물·trail·건조 렌더링은 연결되지 않았다.
spreading beta는 사건 descriptor에만 있다. 비산/퍼짐/후퇴의 광학 transient,
실제 local wet-state, 온도별 물성, 회전 속도 및 freezing도 후속이다.
P1/P2 preview에서 Smear와 legacy local impact film은 계속 제외한다.

## 2. 공급과 면적

`texture/RAIN_BIRTH/dsd.dds`: 128×2 RGBA32FLOAT.
row 0은 네 seed의 CDF, row 1은 D_eq(mm)/V(mm³)/terminal(m/s)이다.
mixture weights와 N0는 s78의 allocation-bounded CPU O(4) 갱신을 쓴다.
GPU는 7회 이진 탐색으로 NUMBER quantile을 뽑고 실제 법선 입사 속도로
도달 여부를 결정한다. 큰 방울의 출현을 단순 intensity multiplier로 늘리지 않는다.

`build_s79_birth_assets.py`가 mask/support 안의 `|dPdu×dPdv|`를 적분했다.
현재 local supported area는 **0.04028860095 m²**이고 실제 model scale²를 적용한다.
2k×512 metric의 셀 적분 근사이며 per-frame/게임 로딩에서 전체 mesh를 다시 읽지 않는다.
기존 physical-area birth sites를 지원 mask와 대조했다. 8192개 모두 지원되고,
site B에 cross(du,dv)와 authored normal의 부호를 넣은 작은 `sites.dds`를 만들었다.
약한 normal agreement 두 site의 최소 |cos|=.07401도 `assets.json`에 기록한다.
부호의 수치 퇴화는 reject하며 실제 outward 방향은 게임 로그로 확인한다.

입사 벡터는 `incidentAirFraction*(wind - carVelocity) - terminal*worldUp`이다.
near-helmet incident air fraction=.30은 **추정 교정값**이다. 몸체 전단의
P1 local-air fraction과 역할이 다르다. 차량 속도를 추가로 더하거나 scalar speed를
법선 충돌 속도로 사용하지 않는다. force wind toggle은 운동용이며 강수 입력 자체를 지우지 않는다.
normal은 transformed du/dv cross의 단위 벡터에 미리 구한 outward 부호를 적용한다.
g-force/camera node transform도 현재 mesh world matrix를 통해 반영한다.
입사 상대속도에는 차량 병진만 사용한다. 검증되지 않은 angular/head-motion 속도는 아직 더하지 않는다.

각 slot proposal은 실제 면적의 `area/count`를 대표한다:

`lambda = N0 * vn * area/count * dt * exposure`.

한 slot/frame에 최대 한 packet. `random<min(lambda,1)`인 NUMBER proposal이 입사한다.
따라서 lambda<1에서 도달 분포는 NUMBER DSD에 vn이 곱해진 분포다.
lambda>1의 나머지는 `V*(lambda-1)`의 expected continuum으로 capacity에 기록한다.
포화 시 큰 packet을 반복 생성하거나 재시도 queue를 쌓지 않는다.
이 부분은 해상도/샘플 budget 때문에 쓰는 명시적인 미해상 근사다.

입사 dt는 실제 sim.dt, 운동은 기존 최대 .05 s dt다. 컴파일 pending 동안
공개하지 못한 frame을 나중에 물량 backlog로 재생하지 않는다. preview 공급 시계는
성공적으로 공개한 step들을 계량한다. 물리 time-loss 및 세부 transport 개선은 후속이다.
track wetness/water/RH, legacy occupancy/density/respawn gap은 공급에 곱하지 않는다.
R1=20 mm/h는 s78의 estimated 시작값이며 CSP 측정 강우율이 아니다.

## 3. 충돌과 보존 분배

`impact_estimated.dds`: logWe 32개 × bare/coat·dry/wet 4행.
각 texel은 attached/film/micro/bounce fraction이며 비음수·합=1이다.
logWe 1.5–4의 완만한 전이를 쓰는 **재질 추정 prior**다. 실제 바이저에서 측정된
임계값이나 보편적인 splash law로 취급하지 않는다. 코팅/젖음에 따라 변화하도록
LUT를 구분했고 material calibration 결과로 교체할 수 있다.
wet override는 기본 0, 수동 local-material 진단값이다. P3 이전에는 actual wet field가 없다.

초기 접선속도는 incoming tangent × .015이다. 이는 추정 impulse fraction이며
0–1 범위라서 부착된 share에 배정된 입사 운동량/에너지를 초과하지 않는다.
물성은 P1과 같은 **20°C 참조 rho=998.2, mu=.001002, gamma=.0728**를 사용한다.
birth 때 We_n/Re_n을 계산한다. beta는 advancing angle을 사용한 energy-balance
근사에서 1–6으로 제한하여 descriptor에만 둔다. 곡면/고속 비산을 실측한 값은 아니다.
[impact/spreading 연구의 모델 식](https://www.sciencedirect.com/science/article/abs/pii/S0009250906008116).

공급 원장:

`V_input = V_attached + V_filmReserve + V_microReserve + V_bounce + V_capacity`.

- airborne D_eq<.25 mm의 attached share는 micro reserve로 간다.
- slot이 차 있으면 attached share를 capacity에 넣고 기존 방울을 바꾸지 않는다.
- film/micro는 새 광학 효과를 덧칠하지 않고 reserve에만 기록한다.
- beta로 equilibrium contact radius/질량을 임의 확대하지 않는다.
- meta.G는 retained 실제 mm³, meta.R은 그 V와 theta에서 유도한 physical contact radius codec이다.
- 표면 병합한 V에는 airborne max D 제한을 적용하지 않는다.

## 4. 같은 사건의 한 번 commit

`rainBirthEvent.hlsl`이 count×4 RGBA32FLOAT immutable event를 만든다.

| Row | 내용 |
|---|---|
| 0 | UV, attached V, next-generation tag |
| 1 | initial raw UV velocity, beta, We_n |
| 2 | input V, film reserve, micro reserve, bounce |
| 3 | capacity, old drop exit V, attached V, sampled arrival count |

state와 meta가 같은 old banks와 같은 event를 읽는다. event tag는 old generation의
다음 generation이어야 하며, dead slot이어야 한다. 이전 event 재적용은 reject한다.
P2 init은 V=0; waiting/occupancy 기반 synthetic respawn 및 legacy birth hold/ramp를 쓰지 않는다.
새 born state의 UV/velocity와 retained V는 같은 frame에 생긴다.

`rain_birth_gpu.lua`의 events → state/meta → 64-slot reduction → totals가 모두
성공해야 bank/tick을 공개한다. 어느 패스가 pending이면 old read banks/totals/tick을 유지한다.
같은 sim.frame의 재-publication도 차단한다. mode/preview/bank reset에서는 source reserve까지
dispose하고 epoch 이전 readback은 폐기한다. 지원 count는 1–4096이며 범위 밖을 거절한다.

`rainBirthTotals.hlsl`은 four-row persistent ledger를 double-buffer한다.
inventory는 new meta의 현재 V를 합산하고, 나머지는 누적 유입/재고/유출이다.
`precise` Kahan compensation으로 장시간 누적값보다 작은 신규 공급이 반올림으로
영구 사라지지 않게 한다. event의 각 slot 합과 원장 totals는 부동소수점 오차 범위에서 일치한다.
exit는 현재 transport의 invalid-position sentinel에서 retire되는 V다. 경계 이탈과
unsupported/iteration bailout은 아직 같은 exit bucket이며 별도 numerical runoff 계량은 후속이다.

## 5. 표시 크기·UI·설치

RainFX → Weather inputs and physical units (P0):

1. P1 SI motion preview ON.
2. GPU heads, lifecycle, mode 3 또는 6 확인.
3. `Enable P2 physical birth preview` ON. 상태/원장은 빈 값에서 시작한다.
4. 기존 estimated rate/power/DSD override와 새 exposure/incident air/impulse/min persistent/wet/normal 교정.
5. `Log P2 actual GPU budget`: 공개된 원장 8개 scalar를 수동 async readback한다.

로그 단위는 mm³. `input-filmReserve-microReserve-bounce-capacity-exit-drops`가 residual이다.
한 frame의 수직 R과 같은 숫자가 아니라 **공개 step의 누적 입사량**이다.
pending 중에는 마지막 공개 원장만 읽고 callback epoch를 확인한다. P0 snapshot과 함께
정차/직진/강수 변화 조건을 대조할 수 있다.

`RAIN_BIRTH_DISPLAY_SCALE=.40`은 기존 display gain에 곱하는 초기 appearance 교정이다.
힘/유입/DSD/V/contact/merge/budget에는 들어가지 않는다. 기존 크기 분포를 정확히 복제한
것은 아니므로 게임에서 룩을 맞춰야 한다. P2 OFF의 head gain은 기존 P1과 동일하다.
일반 P1 toggle OFF는 P2도 끈다. 진단/preview 교정값은 아직 material settings에 영구 저장하지 않는다.

companion installer에 `rain_birth_gpu.lua`를 추가했다. 소스/마지막 설치 hash가 맞는
기존 파일만 갱신한다. shader/texture는 기존 project 링크를 사용한다.
네 개의 작은 DSD/source asset checksum을 최초 한 번 비동기로 확인한다.
KN5/mask mismatch 또는 source/asset stale 상태는 준비를 차단하고 UI 오류를 표시한다.
재생성은 `build_s79_birth_assets.py`; 전체 KN5 migration 빌드에도 이 단계를 추가했다.
새 bake 뒤에는 reload가 필요하다. builder는 NumPy/Pillow 및 기존 cached LuaJIT fixture runtime을 사용한다.

## 6. 비용과 검증

4096-slot GPU source storage:

- events 4096×4×16 = .25 MiB.
- reduction 64×2×16 = 2 KiB, double totals 128 bytes.
- DSD 4 KiB, impact 2 KiB, sites 128 KiB.
- 합≈**.389 MiB**, manual stats 32 bytes 제외. driver/compiler overhead는 포함하지 않는다.

새 패스는 events/blocks/totals 3개이며 화면 해상도와 무관하다. source가 없으면
DSD/source 계산을 건너뛰고, packet이 없는 경우 impact LUT/impulse/spread 계산을 건너뛴다.
per-drop CPU stamping/readback 또는 새 full-resolution normal atlas가 없다.
OFF일 때 source 모듈/캔버스는 만들지 않는다. P2 OFF shader 수치는 동일하지만
업데이트된 shader의 실제 GPU 비용은 게임 Render Stats로 확인해야 한다.

`check_s79_birth_gpu.py`: FXC ps_5_0 `/Ges /WX` + 실제 D3D11 WARP.

- same-event state/meta V·radius·velocity, empty init, generation replay 차단.
- busy slot/micro/high-rate continuum/exit를 포함하는 cumulative inventory balance.
- grazing/backface/reverse-normal, skewed Jacobian 및 reference codec 불변성.
- P2 OFF legacy/P1 state/meta bit-identical to acc0c63.
- production merge+wetpath macro에서 V/momentum 보존.
- 4096 event slots, 65,536 proposals의 실제 DSD/terminal 입사 통계.
- float CDF 끝점의 1 ULP 오차에서 빈 큰 꼬리 bin으로 빠지지 않는 정규화.
- `precise` Kahan이 1e8 mm³ totals에 .5 mm³씩 들어오는 작은 공급을 유지.

128-slot 3-step budget residual은 약 -1.526e-5 mm³ (input55.217 mm³)였다.
real DSD 표본의 number ratio≈.9915, volume ratio≈.9627로 큰 꼬리의 sampling variance가
있으며 정확한 frame별 설정 R과 같다고 주장하지 않는다. GPU report에 variance z-score를 기록한다.

`check_s79_binding.py`: 실제 Lua module/main의 pending 5곳, lazy checksum, 공동 event,
atomic publication, reset/disposal/readback epoch, allocation reuse, OFF 경로를 검증했다.
whole Lua syntax 및 baseline core/legacy shader/settings hash 검사도 통과했다.
이는 실게임 모습/FPS/SDK readback 실행의 확인이 아니다.

결과: `docs/diagnostics/2026-10-14/s79/{gpu_checks,binding_checks,source.diff}`.
다음 게임 gate는 실제 budget, front/outward 방향, retained 크기/운동, P1 대비 비용이다.
그 결과를 반영하여 P3 물 재고의 공간 배분/실제 trail·sheet를 연결한다.
