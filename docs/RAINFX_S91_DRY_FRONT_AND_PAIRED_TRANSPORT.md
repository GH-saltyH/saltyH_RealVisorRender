# RainFX s91 — 건조 전면의 수치 속도 연장과 평균 운동량 전달

Date: 2026-10-16. Status: ACTIVE — **단독 전면과 end/mean 분리 수송의 오프라인 GPU 구현·검증 완료. 서로 다른 전면의 큰 이동 상호작용은 adoption gate 미통과. 게임 runtime은 변경하지 않음.**

## 1. 기준과 작업 범위

사용자가 s90을 커밋한 `2c192e33eddb35e50a8a6b28cbf12242cfb27d8f`에서
이어 진행했다. 사용자 추가 게임 검사가 필요 없는 수치 구현 단계다.
작업 전 runtime/shader/문서136개를 이번 진단 폴더의 `baseline/`에 보존했다.

s90에서 발견한 문제는 film이 없는 셀의 속도0을 특성선 속도로 그대로 써서
움직이는 수막 전면 앞에 정의하지 않은 정체층이 생기는 것이었다.
이번에는 **물량 없이 경로 계산용 평균 속도만 연장**한다. 물리적 접촉선 저항을
새로 정의한 것은 아니며, coat/bare의 미정 물성치를 숫자로 숨기지 않는다.

## 2. 건조 셀의 ghost velocity

입력은 현재 실제 물량, 평균 UV 속도, 정적 유효 row/column run과 메쉬 metric이다.

- 실제 물량이 양수인 셀은 입력 속도의 RGBA 전체를 bit-identical로 유지한다.
  고착된 젖은 셀의0속도를 덮어쓰지 않는다.
- 건조 셀은 같은 연결 run 안의 가장 가까운 젖은 donor를 축마다 찾는다.
  거리 동률은 작은 index를 선택한다. 지원하지 않는 셀/구멍을 넘지 않는다.
- donor가 없는 run은0이다. 전체가 건조한 표면에도 물을 생성하지 않는다.
- 건조 출력 RG(end velocity)는0이고 BA(mean advection velocity)만 채운다.
  이 값을 persistent physical momentum으로 저장하지 않는다.
- donor와 recipient의 축 길이가 다르면
  `meanRecipient = meanDonor * |J_axis,donor| / |J_axis,recipient|`로 보정한다.
  축 접선 방향의 부호 있는 속력 연장이며, 2D geodesic 거리/접촉선 모델은 아니다.

젖음 판정은 실제 `V > 0`이다. 표시 직경/texel gain, rain intensity에 따른
임의의 물량 임계값은 사용하지 않는다. 미세 물량을 잘라내면 별도의 원장 처리가
필요하므로 이번 구현에는 넣지 않았다.

### 검색 비용

16셀 wet bit mask와16 leaf group mask를 사용한다. 두 축을 같은 leaf/group
texture에 pack한다. mask는 float에 정확히 표현되는0..65535 정수이며
`asfloat` subnormal bit 저장을 사용하지 않는다. 1024셀 축의 donor query는
최대4개 group 범위에서 bit 검색하며, 매 셀마다1024 source를 순회하지 않는다.

leaf/group/extension 출력의3패스다. X로 실제 물량을 이동한 다음에는 donor가
달라지므로 Y를 계산하기 전에 다시 만든다. 진단 factory의 잘못된 mass/support
검사는 CPU assert다. **이 extension의 입력 검증을 앱 전체 GPU admission까지
완성한 것은 아니다.** s90 경로/순서 gate와 아래 두 bank 수락은 GPU에서 실행한다.

## 3. end velocity와 interval mean을 따로 전달

유한 관성 predictor에는 step 끝의 속도와 그 step 동안의 평균 속도가 있다.
끝 속도는 다음 step의 실제 운동량 이력이고, 평균 속도는 이번 경로 계산용이다.
X 이동 후 Y에서 원래 위치의 평균을 재사용하면 head가 없는 곳을 보거나
잘못 고착시킬 수 있다. 끝 속도를 평균 대신 쓰면 가속 구간에서 너무 멀리 간다.

이번 연결은 다음 두 packet을 동일한 양수 remap 비중으로 수송한다.

```text
end  = (V_mm3, V * world_end_velocity.xyz)
mean = (V_mm3, V * world_interval_mean.xyz)

SI force predictor (한 번)
 -> 두 packet 준비
 -> mean 접선 재투영 -> dry extension -> X 경로/두 packet remap
 -> 이동된 mean 접선 재투영 -> dry extension -> Y 경로/두 packet remap
 -> end 접선 재투영 + wall reaction -> 다음 physical velocity
```

두 bank는 같은 물을 두 번 보유하는 것이 아니다. V는 같은 비중을 공유하기 위한
중복 payload이며, 실제 물 재고에는 end의 V를 한 번만 센다. 모든 단계에서 두
volume 출력이 bit-identical임을 검사한다. Y 전에는 힘을 다시 적용하지 않는다.

hierarchy/admission draw는 공유한다. leaf 출력은 bounds/end loss/mean loss의
3개 row bank, gather는 end/mean의2H 출력이다. 거부 시 두 packet을 함께 원본으로
유지하고 두 loss를0으로 선택한다. 이것은 여전히 앱의 source/head/clock 전체를
원자적으로 publish하는 transaction은 아니다. 거부한 시간을 수송했다고도 볼 수 없다.

## 4. GPU 검사 결과

모든 아래 검사는 **FXC ps_5_0 /Ges /WX + D3D11 WARP** 실행 결과다.

### 단독 전면·지지·두 packet

- odd grid/random occupancy, 두 축,1024셀 끝/bit15/group 경계의 donor가 CPU
  reference와 일치한다. 젖은 셀 속도는 bit-identical이다.
- 양/음 방향, X/Y 단독 이동·후퇴 전면은1/60초에 정확히4셀 이동한다.
  s90의100→100.864662 정체 반례는 균일 연장 기준104셀에 도달한다.
  이것은 calibrated 실제 바이저 접촉선 속도 측정값이 아니다.
- 빈 표면/고착 patch는 움직이지 않으며, 구멍 반대편으로 donor를 가져오지 않는다.
- 2D patch의 평균 속력은 두 축 각.12m/s, 물리 end 속력은 X .24/Y .48m/s로
  다르게 둔다. 두 축 모두4셀씩 이동하여 centroid(25.5,25.5)에 도달하고,
  end/mean 원장 잔차는0이다. end Y를 썼다면16셀 이동할 조건이다.
- broad-overlap 후보의 GPU 거부에서 두 bank 원본 일치, 두 loss0, recipient work0이다.

### 같은 시간의 compact 전면

평평한.5mm/cell 표면에서 폭40셀의 smooth compact pulse를.12m/s로.1초 이동한다.
이 검사에는 힘/병합/증발이 없으므로 end와 mean은 같다. 예상 이동은24셀,
centroid는84셀이다. L1은 전체 물량1로 정규화한 profile 오차다.

| 항목 |30Hz|60Hz|144Hz|
|---|---:|---:|---:|
| centroid/cell |84.000000|84.000000|83.999974|
| profile L1 |0.00000164%|0.00000164%|0.407192%|
| 물량 원장 잔차 절댓값/mm³ |0|0|1.68e-8 미만|

사전 centroid.001셀/profile1%/packet ledger1e-4 허용치 이내다. 30/60Hz에서는
이동량이 정수 셀에 맞아 특별히 오차가 작다. 일반적인 시간 수렴 차수나 가변
힘/높이 물리의 정확도를 이 결과로 주장하지 않는다.

### 실제 메쉬의 sparse SI step

실제1024×256 cell/2048×512 metric bake 위4251개 유효 셀에만100µm의 합성
patch를 둔다. old velocity0, 중력(0,-9.80665,0)m/s²,
local air(5,0,-10)m/s, dt1/60, P4b pool OFF다. 사용자 리플레이 texture 복원이 아니다.

| 항목 |결과|
|---|---:|
| 시작 물량/mm³ |145.436235789|
| 새로 젖은 셀 |149|
| 물량+runoff 잔차/mm³ |-3.97e-8|
| physical momentum+outflow+wall 잔차 최대 |2.21e-9 미만|
| mean packet 운동량 원장 잔차 최대 |2.00e-9 미만|
| 최대 trace 방문 X/Y |1/1|
| 최대 recipient source 검사 X/Y |32/32|

운동량 packet 단위는 `mm³·m/s`이고 SI 운동량으로는 `998.2e-9 kg/mm³`를 곱한다.
실제 접선 재투영의 wall reaction을 원장에 더한다. 유효하지 않은 메쉬 셀은 비어 있다.
합성 한 step의 연결 검사이며 여러 frame의 variable-height/force 피드백 검사가 아니다.

## 5. 미통과: 서로 다른 전면의 큰 이동

단독 전면 수정으로 일반 high-C film solver가 완성되지는 않았다.
wet40:45셀은1.8m/s(60셀/frame)로 이동하고 wet100:105셀은 정지하도록 두었다.
중간의 빈 공간에서 nearest donor가 바뀌는 지점에 고정된 속도 변화가 생긴다.
현재 frozen Eulerian 특성선은 **실제 액체가 접촉하기 전에 그 지점에 정체/압축을
만든다.** 이 시험에서는 float32 목적 구간 붕괴 status2가 발생했다.

GPU gate는 후보를 거부하고 모든 원래 packet/zero loss를 유지했다. 보고서의
map edge45셀은 이 거부 경로가 돌려준 원본 edge이며, 유효한60셀 수송 결과가 아니다.
보존 검사가 통과해도 이 물리적 경과 시간 검사는 실패다.

따라서 이번 extension을 일반 solver로 게임에 적용하지 않는다. 속도를 줄이거나
dt를 버리거나 물리 직경을 바꾸어 통과시킬 수 없다. dry numerical continuation과
실제 접촉선/충돌 저항을 구분해야 한다.

## 6. 비용과 다음 구현

1024×256에서 한 번 재사용 가능한 extension scratch의 raw 후보는 다음과 같다.

| 자원 |형식·크기|bytes|
|---|---|---:|
| 두 축 leaf |RG32,256×128|262144|
| 두 축 group |RG32,256×8|16384|
| extended mean |RGBA32,1024×256|4194304|
| 합 | |4472832 (4.265625MiB)|

WARP harness는 모든 출력에 RGBA32를 사용한다. 위 수치는 제안한 RG32 allocation의
raw bytes이며, 실제 앱/driver memory 측정이나 총 순증이 아니다.
paired gather는 기존4MiB 출력 대신8MiB 출력, leaf는.5→.75MiB다. 이전 상태와
새 상태의 동시 생존 및 aliasing 계획이 필요하다. 물량 원장 복사는 별도 재고가 아니다.

현재 actual-mesh factory는 predictor/packet 각1, 각 축 mean/extension3/operator6,
마지막 velocity commit1로 **23개의 steady-equivalent standalone draw**를 실행한다.
manual loss/work/wall diagnostic probe는 여기에 포함하지 않는다. 초기 mean은
predictor BA를 그대로 쓸 수 있어22개로 줄일 여지가 있으나 이번 harness는 검증을
명확히 하기 위해 재투영했다. 기존 P3 source/증발/광학과 합친 최종 net 비용은 아니다.
평균 momentum을 따로 remap하는 것보다 hierarchy를 공유하지만, 이 pass 수를
저비용이라고 판정하지 않는다. WARP 실행 시간을 게임 GPU ms로 환산하지 않는다.

다음 단계는 **빈 구간을 사이에 둔 전면 상호작용**이다.

1. 단독 vacuum continuation은 유지하되, 다른 donor가 접근하는 구간을 검출한다.
2. 실제 전면 접촉 이전의 허위 정체와 접촉 이후의 물량/운동량 결합을 분리한다.
   한 frame의 이동이 길어도 먼 곳의 정지 물이 즉시 제동을 전달하지 않게 한다.
3. 국소 상호작용 처리 또는 사건까지의 시간 분할 후보를 비교한다. 전역 CFL만큼
   substep을 늘리는 비용은 피할 대안을 먼저 평가하되, 남은 dt를 버리지 않는다.
4. 다른 속도/반대 방향/분리되는 전면, pinned/coated 접촉선, 여러 frame/동일 시간
   검사로 후보를 선택한다. 그 후 force/source/P4b 및 앱 전체 atomic publish를 연결한다.
5. runtime 채택 전 pass 융합/storage alias와 실제 GPU 비용을 검증한다.

## 7. 전달과 재현

현재 게임 물리/광학/튜닝/material/geometry assets의 변경은0이다. 앱 reload나
사용자 추가 로그가 필요 없다. Git commit/push는 하지 않았다.

- `prototypes/s91/extend*.hlsl`: bounded occupancy/ghost extension.
- `prototypes/s91/paired*.hlsl`, `meanVelocity.hlsl`: end/mean payload와 재투영.
- `tools/s91_extension_reference.py`, `s91_paired_reference.py`: 오프라인 factory.
- `tools/check_s91_extension.py`: donor/전면/지지/metric6개 검사 그룹.
- `tools/check_s91_paired_transport.py`: 두 축 평균 전달/공유 수락.
- `tools/check_s91_force_geometry.py`: sparse 실제 메쉬/SI/원장.
- `tools/check_s91_equal_time_and_interaction.py`: compact 동일 시간 및 high-C 반례.
- `diagnostics/2026-10-16/s91/*checks.json`, `delivery.json`, `source.diff`: 결과·보존 감사.
