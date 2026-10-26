# RainFX s93 — 압축 가능한 수송과 응집 위치 이력

Date: 2026-10-16. Status: ACTIVE — **오프라인 pressureless 수송 후보 구현. 실제 메쉬의 두 축 보존/정지 안정성/단일 축 응집 이력 검사 통과. 두 축 이력·힘/source/clock 결합과 실제 비용 검증 전이므로 게임 runtime은 변경하지 않음.**

## 1. 기준과 결론

사용자가 다음 구현을 바로 진행하도록 승인했다. HEAD는 s90 사용자 커밋
`2c192e33eddb35e50a8a6b28cbf12242cfb27d8f`이며 s91/s92 로컬 결과도 보존했다.
runtime/shader/문서 및 이전 prototype/tools168개를 이번 `baseline/`에 보존했다.

s92의 축 폭 고정 제약을 제거했다. 물량은 유지하면서 여러 source의 물을 같은
영역에 모아 **격자 수막 두께가 증가**할 수 있다. 메쉬4251셀 합성 patch가
s92에서는 전부 거부됐지만 이번 resolved-cell 수송은 X/Y 모두 수락된다.

이번 단계는 **압력과 접촉선 힘을 제외한 수송 연산**이다. 정확한 연속체 shock,
실제 바이저의 표면장력/접촉각/고착 임계값을 검증한 모델은 아니다. P0 날씨,
P1/P2 물방울의 SI 질량·직경·힘, 6px/mm calibration이나 표시 gain을 바꾸지 않았다.

### 구현 중 비교한 표현

| 표현 |결과|
|---|---|
| 가변 폭 endpoint + 일반 중심/분산 이력 |압축/단독 이동은 통과하지만 혼합 상태의 정지 보존 실패. 일반 이력으로 미채택|
| resolved cell 중심의 질량점 |정지·보존·실제 메쉬 통과. 강한 충돌 후 반복 재분배에서 시간별 형태 차이가 큼|
| resolved cell + **완전한 응집 구역의 공통 위치만 유지** |혼합 정지 반례와 단일 축 반복 응집 검사 통과. 다음 결합 후보|

Python factory의 기본값은 최소 resolved-cell 연산 `cell-centres`다.
`coherent-points`가 응집 위치를 추가하는 단일 축 후보이며, 아직 다른 축과
source/force 갱신까지 이 이력을 넘기는 구현은 없다. `moments`는 실패 원인을
재현하는 연구 모드다. 게임 설정/UI가 새로 생긴 것은 아니다.

## 2. 폭 제약 없이 물량을 모으는 연산

선택한 resolved-cell 모드에서 source의 질량은 해당 셀 중심의 수치 질량점으로
표현한다. 이는 **실제 물방울의 반경이0이라는 의미가 아니다.** 수막 격자 재고의
이동을 계산하는 표현이다. 평균 UV/s로 자유 위치를 계산한다.

```text
freePosition_i = cell_i + .5 + intervalMeanVelocity_i * axisGridSize * dt

순서 제약: position_i <= position_(i+1)
뒤집힌 그룹 position = sum(V_i * freePosition_i) / sum(V_i)
```

부피 가중 PAVA를 사용하되 s92의 `prefixWidth`를 빼거나 폭1을 강제하지 않는다.
다른 위치의 물이 한 점으로 모이는 것을 허용한다. 처음부터 연속인 수막도
전체 row를 단단한 덩어리로 묶지 않는다. 셀에 도착한 V와 실제 메쉬 면적 A로
`h = V/A`를 계산하므로 물량 집중이 해상도에서 분해된 두께 증가로 이어진다.

소스 자체의 end/mean world momentum은 경로 생성 전후에 그대로 두고,
**실제로 전달된 물량의 비중**으로 gather한다. 같은 위치로 모인 source들은
동일한 양수 비중을 받아 물량 가중 운동량으로 혼합된다. 셀 크기 범위 안에서는
추가 수치 혼합/확산이 있다. 물리적 pressure/contact-line 저항과 구분한다.

### 제거한 잘못된 운동량 처리

초기 endpoint 원형에서는 셀의 가상 양 끝에 V/2를 두고, 경계 접촉 시 그
V/2 운동량을 통째로 먼저 섞었다. 이 방식은 작은 dt에서도 큰 감속을 줄 수 있어
제거했다. 당시 원형/결과는 `lumped_endpoint_trial/`에 보존했다.

현재 source packet은 gather 직전까지 bit-identical이다. sinusoidal 속도장의
dt.001/.0001초 검사에서 물량 가중 속도 변화는 각각
`2.8924932e-4 / 2.8919206e-5`로, 비율10.00198이다.
시간을10배 줄였는데 같은 충격량을 다시 주는 동작은 이 검사에서 제거됐다.
일반적인 시간 수렴 차수의 증명은 아니다.

## 3. 양수 deposit, 경계, 탐색 제한

폭이 있는 연구용 구간은 source-local overlap 비중으로 deposit한다. 폭0인
resolved point는 가장 가까운 두 cell centre에 선형 비중(CIC)으로 deposit한다.
어떤 source도 표시 gain으로 물량/운동량이 달라지지 않는다.

- point의 실제 위치가 원래 연결 run 안이면, 그 run의 유효 recipient에만
  kernel을 정규화한다. 밖의 마른 구멍/다른 연결 run에는 물을 만들지 않는다.
- point 위치가 run 밖이면 전체 runoff다. 수치 kernel 일부가 경계를 넘었다고
  정지 point의 물을 매 frame 조금씩 버리는 오류를 피한다.
- 유한 폭 source는 run 밖으로 나간 비중만 유출한다.
- point의 경계 통과 시점/위치는 격자 해상도의 근사다. 경계 부근에서 정규화한
  grid centroid가 실제 point와 다를 수 있다. 경계 subcell 정확도까지 주장하지 않는다.

한 source당 앞뒤16개, 총33개 젖은 source만 찾는다. 수락 그룹은 최대16개다.
큰/불완전 그룹이나 서로 맞지 않는 certificate는 거부한다. 연구용 endpoint
모드의 window는66 endpoint, cap32 endpoint다.

leaf/group는 **물리적 위치 순서**와 **kernel traversal bbox**를 따로 저장한다.
같은 point의 격자 kernel이 겹치는 것까지 순서 역전으로 거부하지 않는다.
실제 위치가 뒤집힌 후보는 GPU admission이 거부하고 original end/mean을
선택한다. history 모드에서는 이력도 같은 GPU flag로 원복하고 loss0을 선택한다.

거부는 안전한 상태 유지이며 유효한 경과 시간 수송은 아니다. 큰 그룹 처리와
앱 clock/source의 동기화는 runtime 채택 전 gate다. fixture 검증 일부는 CPU
assert이며 production의 모든 비정상 입력 처리가 구현된 것은 아니다.

## 4. 일반 모양 이력의 반례와 응집 이력

중심/분산으로 셀 안의 구간을 복원하는 연구 모드는 단독 fractional 이동을 잘
유지했지만, 여러 수치 kernel이 섞이면 실제로 없는 구간을 복원할 수 있다.
두 point가 같은 셀의 다른 위치에 도착한 뒤 속도를0으로 둔 반례에서,
**0.2mm³ 중 물량 분포 L1이.0655524mm³ 변했다.** 총 물량 보존만으로
이 문제를 검출할 수 없다. 일반 material-moment 이력을 채택하지 않는다.

resolved-cell 중심만 쓰면 이 정지 반례는 bit-identical이다. 그러나 강한 응집을
잘게 나누어 계산할 때 응집된 물을 다시 cell centre들에 분산시키므로 원형이
퍼진다. 이를 보완하는 `coherent-points`는 다음 조건에서만 공통 위치를 유지한다.

1. 해당 recipient의 모든 기여가 같은 point에서 왔어야 한다.
2. 그 point의 **전체 유효 CIC image**도 같은 공통 위치로만 채워져 있어야 한다.
3. 한쪽 image가 다른 물과 섞였다면 반대쪽의 얼핏 순수한 image도 이력을 버린다.
4. 이력은 다음 경로의 위치에만 사용한다. 물량을 추가하지 않으며 원본 운동량도
   이력 인증만으로 바꾸지 않는다.

한 recipient의 순수성만 검사하면 다른 image에 섞여 들어간 물을 놓쳐 정지 상태가
변할 수 있다. 추가 GPU certificate pass가 전체 image의 일치를 확인한다.
표현 가능한 동일 위치 판단에는 `4 * float32 epsilon * max(|position|,1)`의
수치 허용치를 쓴다. mm 크기/표면 저항에 대한 보정 계수가 아니다.

history payload는 `(cell centre 기준 offset, 0, 진단 volume, coherent flag)`다.
현재는 한 축용이다. 다른 축의 gather에 위치·동일 구역 관계를 넘기거나 새 물,
증발/P4b가 이력을 바꿀 때의 처리는 다음 단계다. SI 힘도 이 image들을 서로
다른 독립 덩어리로 잘못 평가하지 않도록 후속 결합 검사가 필요하다.

## 5. 검증 결과

아래는 **FXC ps_5_0 /Ges /WX + D3D11 WARP** 실행 결과다.

### 비교 가능한 검사의 범위

- 전체 run double-precision CPU PAVA/deposit와16row/128개 서로 다른 질량·
  부호 있는 XYZ end/mean packet을 비교했다. map 오차 약1.23e-5셀,
  recipient payload 오차 약7.14e-6 이내, 원장 잔차는1e-5 이내다.
- CPU reference는 정의한 수치 projection의 일치 검사다. 정확한 연속체 shock
  해석해나 실제 바이저의 접촉각 측정값이 아니다.
- 연구용 유한 구간의 약한 압축에서100개 연속 wet cell이 수락되고 폭이
  약.90–.95셀로 줄며 peak 물량.1→.111112가 된다. s92의 rigid-row 제약을
  제거한 분리 검사다. 주 후보의 source support는 처음부터 수치 point이므로
  report의 point count를 실제 액체가 전부 붕괴한 수로 읽으면 안 된다.
- source40:45와100:105의 양/음 방향 X/Y 단독 접촉 전/후와 zero-width deposit,
  부호 있는 운동량·공간1차 moment 검사를 통과했다.
- run 경계 부분 유출/point 유출/경계 정지 point3회/큰 그룹의 GPU 전체 거부도
  검사했다. 거부에서 원래 packet/history 일치와 loss0을 확인했다.

### 실제 메쉬의 SI 연결

s91/s92와 같은 synthetic100µm/4251셀 patch, old velocity0,
중력 및 local air(5,0,-10)m/s, dt1/60, P4b/source/증발 OFF 조건이다.
사용자 리플레이 texture를 복원한 검사가 아니다.

```text
SI predictor(end, mean) -> physical end/mean packet
 -> mean 재투영 -> X resolved-cell projection/deposit
 -> 이동한 mean 재투영 -> Y resolved-cell projection/deposit
 -> end 접선 재투영 + wall reaction
```

| 지표 |결과|
|---|---:|
| 수락 |X/Y 모두 수락|
| 시작 물량/mm³ |145.436235789|
| 새로 젖은 셀 |149|
| 물량+runoff 잔차/mm³ |-2.304e-7|
| world momentum+outflow+wall 잔차 최대 |2.794e-9|
| peak resolved film/µm |103.0594|
| 최대 recipient source 검사 X/Y |32/32|

packet 운동량 단위는 `mm³·m/s`, SI 변환 계수는 `998.2e-9 kg/mm³`다.
이 검사는 이력을 되먹이지 않는 resolved-cell 모드의 **한 frozen-force split step**이다.
응집 이력까지 연결한 다중 frame 게임 물리 검증으로 확대해서 해석하지 않는다.

### 동일 시간과 정지 검사

폭40셀 compact profile을.123m/s로.03초 이동시켰다. 예상 centroid67.38셀이다.

| resolved-cell profile 상대 L1 |30Hz|60Hz|144Hz|
|---|---:|---:|---:|
| analytic translation 대비 |.184441%|.228172%|.838121%|

centroid 오차는4.11e-6셀 이내, 물량 원장 잔차1.25e-8 이내다. 사전 profile2%/
centroid.01셀/원장1e-6 기준을 통과한다. 수치 확산이 남고 Hz 증가 시 형태 오차가
반드시 줄어드는 방법은 아니다.

강한 두 patch 충돌의.03초 결과를 비교하면 다음과 같다.

| 단일 frozen projection 대비 profile L1 |30Hz|60Hz|144Hz|
|---|---:|---:|---:|
| resolved-cell만 재분배 |.000733% 미만|.000733% 미만|약99.9993%|
| 완전 image 인증을 한 응집 이력 |0%|0%|0%|

응집 이력 조건에서 centroid126.5셀, 모든 step 수락, 물량 잔차0,
운동량 원장 잔차2.99e-8 미만이다. 최종 point가 cell centre에 맞는 이 검사의
특수성이 있다. 별도로 noninteger 최종 위치48.18셀의 단독 point도 검사했다.
30/60/144Hz에서 두 유효 image가 유지되며 centroid 오차7.33e-6셀 이내다.

두 point의 한 image가 다른 물과 섞이는 정지 반례에서는 모든 관련 history를
해제하고 정지 packet을 bit-identical로 유지한다. 특정 단일 축·고정 힘 시험의
통과이며 모든 방향/강우/source/압력/다중 frame 수렴의 통과는 아니다.

## 6. 비용과 다음 구현

resolved-cell 원형을 한 mass point/source로 특화해 endpoint66개 배열/2H 출력을
33개 배열/H 출력으로 줄였다. 사전 전체 셀 운동량 혼합 pass도 제거했다.

| 단계 |resolved-cell|응집 이력 후보|
|---|---:|---:|
| packed wet leaf/group |2|2|
| point projection + certificate 검증 |2|2|
| remap leaf/group/admission/gather |4|4|
| 전체 image history 인증 |0|1|
| 한 축 합(앞의 mean 재투영 제외) |8|9|

mean 재투영/축과 SI predictor/packet/velocity commit3패스를 더하면
두 축 단순 합계는21/23패스다. **응집 이력의 두 축 전달은 미구현이므로23은
추정이며 완성된 두 축 이력 solver의 실행 횟수가 아니다.** manual work/loss
probe는 제외했다. P3 source/광학과 결합한 최종 net 비용도 아니다.

1024×256 RGBA32에서 resolved point certificate4MiB, interval4MiB,
두 packet gather8MiB다. 응집 이력 모드는 gather12MiB와 추가 history4MiB 출력이
필요하다. leaf4bank는1MiB, group2bank는.03125MiB다. 이전 상태/중간 상태의
동시 생존·aliasing과 실제 앱 memory는 아직 계량하지 않았다.

실제 GPU ms/FPS는 측정하지 않았다. pass/배열/출력 크기를 줄였지만 저비용
runtime이라는 결론을 내리지 않는다. WARP 시간도 게임 GPU 시간으로 환산하지 않는다.

다음 구현:

1. 공통 응집 위치와 전체 image 관계를 X/Y 양쪽에서 전달하고, 축 순서/회전/
   서로 다른 속도·분열·혼합·정지를 검사한다. 단일 축 이력을 다른 축에 그대로 쓰지 않는다.
2. 해당 이력과 실제 유한 관성 force/height 갱신을 결합한다. 응집 물의 수치 image를
   각각 독립된 물 덩어리로 오인하지 않도록 검사한다.
3. 새 source/evaporation/P4b와 V·end momentum·mean·history·clock을 같은 GPU
   generation으로 publish한다. 큰 그룹/미준비 후보의 남은 dt 처리도 포함한다.
4. pressure/contact-line closure와 공간/시간 해상도, pass 융합/실제 게임 비용을
   확인한 뒤 preview를 설치한다. 단순 pressureless 응집을 최종 물성 모델로 간주하지 않는다.

## 7. 산출물과 현재 게임

현재 게임 runtime53개, 튜닝·사용자 native material·geometry assets를 보존했다.
앱 reload나 추가 게임 로그는 필요 없다. Git commit/push도 하지 않았다.

- `prototypes/s93/fluidCells*`: 선택한 point projection/certificate.
- `fluidRemapCommon/Leaves/Groups/Accept/Gather/Loss`: 양수 deposit/원장/선택.
- `fluidCoherentHistory`: 전체 image 이력 인증.
- `fluidNodes/Intervals/Common`: 가변 구간과 실패한 일반 moment 모드의 재현.
- `tools/s93_fluid_reference.py`: 오프라인 factory/독립 CPU projection.
- `tools/check_s93_*.py`: 기본 구간, 실제 메쉬, 정지/시간, 임펄스, 응집/원장 검사.
- `diagnostics/2026-10-16/s93/*checks.json`, `delivery.json`, `source.diff`: 결과·감사.
