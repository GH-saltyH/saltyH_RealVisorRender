# RainFX s90 — 속도 기반 경로 생성과 곡면 보존 수송 연결

Date: 2026-10-16. Status: ACTIVE — **실제 SI predictor→경로→양수 remap의 오프라인 GPU 연결 구현.** 처방 속도장 시간/보존·메쉬 지지·GPU 축 수락 검증 통과. 건조 전면 closure와 전체 앱 transaction은 미완료. 게임 물리는 변경하지 않음.

## 1. s89에서 추가한 구현

사용자는 positive_remap 확인 후 다음 구현을 요청했다. s89의 목적 구간은 시험
입력으로 주어졌지만, 이번에는 **공간 속도장을 적분해 셀 양끝의 목적 구간을
실제로 생성**한다. s88의 SI predictor가 출력한 step 평균 UV/s를 입력으로 사용한다.
표시 직경/texel gain은 입력이 아니다.

작업 전135개 runtime/shader/문서를 `diagnostics/2026-10-16/s90/baseline/`에
보존했다. 새 구현은 `docs/prototypes/s90/` 및 검사 factory에 있다. production
Lua/HLSL과 사용자 튜닝·material·geometry assets는 그대로 보존한다.

## 2. Frozen 특성선과 기하 지지

### 경로 생성

- 인접 셀의 평균으로 공통 face velocity를 만들고 셀 내부를 선형 보간한다.
- `dx/dt = v_left + slope * (x - cell_left)`를 구간 안에서 지수식으로 적분한다.
  face까지 도달하는 시간은 로그식으로 구한 뒤 남은 시간을 다음 구간에 쓴다.
- 정체점에 가까워지거나 반대 방향의 흐름이 만나는 경우, 유한 시간에 face
  순서를 뒤집지 않는다. 작은 slope에는 급수를 사용해 상쇄 오차를 줄인다.
- **정확히 affine인16셀 block**은 한 번에 통과한다. tolerance 기본0이며
  임의의 속도 평탄화/축소를 하지 않는다. 균일60.25셀 이동의 최대 방문은5회다.
- 최대128회 탐색이다. 초과·비정상 입력·float32 구간 붕괴는 status를 세워
  후보를 거부한다. 도중까지만 이동시키거나 남은 dt를 몰래 버리지 않는다.

이는 **step 동안 고정한 Eulerian 속도장**의 경로다. 시간에 따라 변하는 film
높이/압력/속도를 함께 푼 완전한 유체 시뮬레이션은 아니다. 두 축은 순차 분리하며
현재 원형은 각 축 full dt다. 비가환 곡면 흐름에서 splitting 오차가 남는다.

### 지원 구간과 구멍

기존 정적 cell 면적/유효 metric에서 각 셀의 연결된 row/column 구간을 만든다.
run의 RG는 가로, BA는 세로의 반열린 cell 범위다. 현재는 진단 폴더에 `.npy`로
만들었고 설치용 DDS나 production bake manifest는 수정하지 않았다.

한 source의 목적 구간은 **그 source가 속한 연결 구간으로만** deposit한다.
범위 밖으로 나간 비중은 runoff와 유출 운동량으로 계량한다. 원래 구간을 나온
물의 연장선이 다른 유효 구간 위에 있어도 그곳에 재생성하지 않는다.
경계 밖 구간 연장은 유출 비중 계산을 위한 좌표이며 외부 물 시뮬레이션이 아니다.
원본 bake 셀보다 작은 구멍의 정밀 지지까지 증명한 것은 아니다.

## 3. 수치 확산을 줄인 source 복원

여러 번 remap하면 piecewise-constant source가 확산된다. 같은0.2초를 계산한
첫 시험에서144Hz 압축 Gaussian의 상대 profile L1 오차가2.614%였다.
source mass의 이웃 차분에 minmod limiter를 적용해 source 내부를 선형 복원했다.

```text
source profile(t) = mass + slope * (t - .5),  0 <= t <= 1
slope = limited minmod(mass-left, right-mass)
fraction(q0,q1) = (q1-q0) * [1 + .5*slope/mass*(q1+q0-1)]
```

같은 **양수 적분 비중**을 물량과 세 운동량 채널에 적용한다. 셀 전체 적분은
원래 packet과 같고, source의 실제 접선 속도는 source 안에서 일정하다고 둔다.
연결 구간 밖의 이웃은 자기 값으로 처리해 경계를 가로지르는 기울기를 만들지 않는다.
추가 pass/storage는 없지만 기여 source마다 이웃 mass 조회 두 번 등이 늘어난다.

이는 실제 diffusion 계수를 바꾸거나 수막 높이를 키운 보정이 아니다. 고착/
접촉선 물리를 추가한 것도 아니다. 경계 runoff도 같은 선형 적분을 사용한다.

## 4. GPU에서 후보 전체를 수락하는 축 gate

s89의 임의 source 구간은 넓게 겹치면 row N² 탐색이 가능했다. 공통 특성선에서
생성한 유효 구간은 source 순서를 유지한다. 이번에는 이 조건을 GPU에서 확인한다.

1. leaf는 **연결 구간으로 clip한 실제 retained bounds**를 사용한다.
   source status와 leaf 안의 순서 역전을 기록한다.
2. group는 leaf 순서와 status를 모은다.
3. 1×1 GPU admission pass가 모든 row/group를 검사한다.
4. 수락했을 때만 recipient traversal과 remap을 실행한다.
5. 거부했을 때는 해당 축의 **모든 old packet을 bit-identical로 유지**하고
   source runoff를0으로 선택한다. 수신 후보 순회도0이다.

균일1024셀 row의 실제 source 검사 합계는16384, 순서가 유지되는 경우의
보수적 상한 `16*(N+2*ceil(N/16))`은18432다. 개별 압축 셀은 여전히 많은
source를 검사할 수 있다. 모든 retained leaf 구간이 순서대로 겹치지 않아야
이 전체 row 상한을 적용할 수 있으며, 임의 broad-overlap은 수락하지 않는다.

**이것은 앱 전체 원자적 publish gate가 아니다.** 거부 시 정지한 축에 대해
경과 시간을 정확히 수송한 것도 아니다. 향후 runtime은 상태/새 source/head
debit/clock과 함께 fallback을 계량하고, 잘못된 후보가 일부 bank만 갱신하지
않도록 기존 P2/P3 transaction에 연결해야 한다. 여기서는 manual loss probe로
후속 runoff 소비자가 써야 할 동일한 GPU flag도 검사했다. 이 probe는 제안된
steady pass 수에 넣지 않는다.

## 5. 실제 SI 힘·메쉬와의 연결 검증

`tools/check_s90_force_geometry.py`가 실제 `rainSurfaceMetric`, `rainPhysicsSI`,
P4b pool address/debit 및 s88 유한 관성 predictor를 실행한다.

**합성 조건:** 실제1024×256 cell bake/2048×512 du,dv, 유효 셀 전체100µm,
old velocity0, 중력 및 local air=(5,0,-10)m/s, dt=1/60. 한 synthetic P4b
수락 event에서.013576488mm³를 차감한다. 사용자 영상의 texture를 복원한 시험은 아니다.

연결 순서:

```text
previous film - accepted pool debit
  -> SI predictor(end velocity, interval-average UV velocity)
  -> physical volume + world-momentum packet
  -> X trace/remap -> Y trace/remap
  -> recipient tangent velocity + explicit wall reaction
```

| 지표 | 결과 |
|---|---:|
| 실제 유효 메쉬 셀 |123224|
| 시작 film/mm³(pool 차감 후) |4028.846598|
| 두 축 체적+runoff 원장 잔차/mm³ |6.96e-7|
| 유출·곡면 반력 포함 운동량 잔차 최대 |1.14e-8|
| 실제 메쉬 합성 step 최대 trace 방문 |2|
| grid 전체 평균 source 검사 X/Y |7.994/7.993|
| 최대 source 검사 X/Y |32/32|

packet 운동량 단위는 `mm³·m/s`이며 물의 실제 운동량으로 바꾸려면
`998.2e-9 kg/mm³`를 곱한다. 곡면 접선 재투영으로 벽에 전달된 운동량은
반력 항으로 따로 더한다. 전역3D 운동량을 무조건 그대로 유지했다고 주장하지 않는다.
display 계수 변경에서 predictor는 bit-identical이다.

## 6. 시간과 오류 검사

FXC ps_5_0 **/Ges /WX**, D3D11 WARP에서:

- 공통 속도장으로부터 얻은 압축/확장 경로와 해석해의 endpoint 오차 최대
  약6.01e-5셀. 같은 endpoint를 입력으로 준 s89 검사가 아니다.
- 정체점에서 순서 유지. 한 셀 구멍의 장거리 통과/부분 유출에서 물과
  부호 있는 운동량의 원장 유지.
-128회(테스트에서1회로 강제한 경우 포함) 초과 및 비정상 입력을 status로 거부.
- broad-overlap·탐색 초과 후보의 GPU 거부에서 old packet 일치, loss0,
  recipient visit0.

0.2초 동안 처방한 속도장의 Gaussian 밀도를30/60/144Hz로 반복 수송했다.
아래 L1은 공간 전체 질량1로 정규화한 profile 오차이며 속도 오차가 아니다.

| 시험 |30Hz|60Hz|144Hz|
|---|---:|---:|---:|
| 균일 이동 profile L1 |.0194%|.0395%|.0914%|
| 압축 profile L1 |.0542%|.0688%|.1582%|

설정한 profile 허용치.3%, centroid.01셀, mass ledger1e-4 이내를 통과했다.
가장 큰 centroid 오차는 약4.65e-5셀, ledger 절댓값은 약6.72e-8이다.
remap 횟수에 따른 차이는 남고, 고정 grid에서 Hz만 높이면 shape 오차가
단조 감소한다는 주장은 하지 않는다. 높이/속도 피드백·접촉선·실제 게임
frame dt 변동까지 통과했다는 의미도 아니다.

## 7. 게임 연결 전에 발견한 건조 전면 문제

현재 SI predictor는 film이 없는 셀에서 속도를0으로 출력한다. 이 값을 그대로
Eulerian tracing에 쓰면, 젖은 전면 옆에 **수치적으로 생긴 정체층**이 만들어진다.

재현: source90..100셀에240셀/s, 그 밖의 건조 셀 속도0, dt=1/60.
오른쪽 전면은100→100.864662셀이다. 같은 속도를 건조 쪽에도 연장한
free-flight 기준은104셀이다. 이것은 실제 바이저 전면이 반드시104셀이어야
한다는 관측값이 아니다. 현재 모델에 정의하지 않은 접촉선 저항을 “건조 속도0”이
대신 만들어낸다는 점을 드러내는 분리 검사다.

따라서 **새 transport를 아직 게임에 연결하지 않는다**. 수치적 0을 고착력으로
재해석하거나, 물리 두께·직경·출력 gain으로 전면 문제를 보정하지 않는다.
다음 구현은 다음 계약을 우선한다.

1. 건조 셀에는 물을 생성하지 않으면서, 움직이는 액체 전면의 advective velocity를
   정의하는 extension 또는 유한 질량 packet/front closure.
2. 재질의 실제 고착/접촉선 저항과 이 extension을 분리. 미정 계수를 물리 상수로
   숨기지 않고 low-rain/coat/bare와 정지/이동을 함께 검사.
3. 이후 variable-height/force·momentum history, P4b 복귀, 신규 source/증발과
   전체 앱 GPU 수락·원장을 연결. 실제 게임 ms/장시간 memory gate 진행.

## 8. 비용과 전달

현재 분리한 operator는 한 축에 affine-block, trace-map, leaf, group, admission,
gather로 **6패스**다. 두 축12패스이며 그 앞의 predictor/packet bridge와 뒤의
velocity commit은3패스다. P3의 새 source/증발/광학과 결합한 최종 net pass 수가
아니다. 자주 쓰는 값을 미리 합치고 stage를 융합할 여지는 다음 비용 검토 대상이다.

한 축용 주요 raw payload 후보: static runs RGBA16 2MiB(현 진단 npy는RGBA32
4MiB), RGBA32 map4MiB, affine blocks.25MiB, leaf bounds/loss.5MiB,
group.015625MiB, admission16bytes. packet buffers와 predictor/velocity history는
별도이며, 최종 alias 설계 전에는 전체 순증을 확정하지 않는다.
정적 run은 bake 단계 대상이고, 게임 로드시 긴 CPU row scan을 추가하지 않는다.
지금은 실제 GPU ms/FPS를 측정하지 않았으며 저비용 runtime이라고 판정하지 않는다.

**게임 쪽 변경은0**이다. s89 view6, 물리/날씨/직경/사용자 튜닝과 native
material은 그대로다. 앱 reload/새 로그 측정은 필요 없다. Git commit/push도 하지 않았다.

### 산출물

- `prototypes/s90/trace*.hlsl`: tracing, reconstruction, GPU admission, packet/velocity bridge.
- `tools/s90_transport_reference.py`: shader factory, 정적 run/reference 조합.
- `tools/check_s90_characteristics.py`: 속도장 경로·지지·동일 경과 시간 검사.
- `tools/check_s90_force_geometry.py`: 실제 메쉬/SI predictor 연결·반력/원장.
- `tools/check_s90_admission_and_front.py`: GPU 후보 거부·비용 상한·건조 전면 반례.
- `diagnostics/2026-10-16/s90/*checks.json`, `delivery.json`: 결과와 보존 감사.
