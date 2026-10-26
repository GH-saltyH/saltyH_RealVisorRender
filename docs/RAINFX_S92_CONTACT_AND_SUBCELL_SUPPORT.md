# RainFX s92 — 전면 접촉 후보와 부분 젖음 폭 보존

Date: 2026-10-16. Status: ACTIVE — **유한 폭 패킷 접촉/부분 폭 이력/GPU 전체 후보 수락 구현. 단독 접촉 수치 검증 통과. 연속 수막용 물리 모델로는 부적합하므로 runtime에 채택하지 않음.**

## 1. 시작 상태와 목적

사용자는 s91 후 다음 구현 진행을 승인했다. Git HEAD는 여전히 사용자가 찍은
s90 `2c192e33eddb35e50a8a6b28cbf12242cfb27d8f`이고, s91 로컬 결과도 보존했다.
작업 전 runtime/shader/문서 및 s91 prototype/tools151개를
`diagnostics/2026-10-16/s92/baseline/`에 복사했다.

s91의 nearest-donor ghost field는 빠른 전면과 먼 정지 물 사이의 빈 공간에서
허위 정체를 만들었다. 이번 후보는 **실제 물이 있는 패킷만 자유 이동시키고,
겹치려는 패킷들의 접촉을 계산**한다. 건조 셀의 속도장을 보간하지 않는다.
표시 직경, texel gain, intensity는 이 접촉 계산에 들어가지 않는다.

이는 후보 비교를 위한 수치 모델이다. **패킷의 축 방향 폭을 보존하는 비탄성
접촉 제약**을 먼저 구현했으며, 액체 압력/접촉각/표면장력 모델을 얻었다고
해석해서는 안 된다. 실제 메쉬 검사에서 이 제약의 부적합성도 확인했다.

## 2. 접촉 연산과 제한된 GPU 탐색

한 연결 run의 젖은 source를 순서대로 나열한다. 각 source는 물량 `V_i`,
현재 셀 안의 실제 지지 구간 `[a_i,b_i]`, 평균 축 이동 `d_i`를 가진다.
초기 지지를 지정하지 않은 검사는 셀 전체 `[0,1]`로 시작한다.

```text
w_i = b_i - a_i
prefix_i = 이전 젖은 패킷 폭의 합
freeLevel_i = sourceCell_i + a_i + d_i - prefix_i

접촉 제약: level_i <= level_(i+1)
그룹 level = sum(V_i * freeLevel_i) / sum(V_i)
목적 구간 = [그룹 level + 그룹 내부 prefix_i,
             그룹 level + 그룹 내부 prefix_i + w_i]
```

가중 순서 회귀(PAVA)로 뒤집히는 인접 그룹을 합친다. 독립 CPU reference는
run 전체를 double precision으로 계산하고 GPU는 local window로 계산한다.
물량 가중 그룹 평균으로 end/mean의3D 운동량을 각각 분배한다. 두 bank의 V는
같은 재고를 중복 표현한 것이므로 원장에는 한 번만 센다.

고정 힘/평면의 유한 폭 비탄성 접촉 후보 안에서 CPU와 비교한 결과다. 그룹 전체의
즉각적인 운동량 평균은 유체 안의 유한 속도 압력 전달이나 calibrated 부착력과 다르다.
붙어 있던 물의 adhesion threshold를 새로 구현한 것도 아니다.

### GPU 탐색 계약

- s91의16셀 leaf/16 leaf group wet mask를 재사용한다.
- 자신과 앞뒤 최대16개 젖은 패킷, 총33개만 본다. 빈 셀 거리에 비례한
  전역 CFL substep을 추가하지 않는다.
- 수락 가능한 접촉 그룹은 최대16개 패킷이다. window 끝에 걸친 불완전 그룹,
  서로 맞지 않는 그룹 certificate, 목적 구간 순서 역전은 거부한다.
- 각 source가 그룹의 동일한 첫 source부터 다시 합산하여 공통 level을 얻는다.
  공유 endpoint는 같은 덧셈 순서와 `precise`로 계산한다. singleton은
  `mass * position / mass`를 거치지 않고 직접 자유 이동 위치를 쓴다.
  float32의 아주 작은 가짜 구간 겹침 때문에 정상 후보를 거부하던 문제를 수정했다.
- 큰 그룹을 일부만 섞거나, 거부한 축의 시간을 수송했다고 처리하지 않는다.

## 3. 반복 갱신에서 찾은 부분 젖음 이력 문제

첫 구현은 매번 젖은 셀을 폭1 패킷으로 다시 만들었다. fractional 이동 뒤
가장자리 셀에는 물이 일부만 있지만, 다음 frame에서 전체 폭으로 재생성되었다.
물량과 운동량은 맞아도 실제 젖은 폭/접촉 시점/형태가 달라진다.

이번에는 gather의 세 번째 bank에 recipient의 **기하학적 젖은 구간**을 남긴다.

```text
R/G = recipient cell 내부의 젖은 구간 시작/끝
B   = 기여한 구간 길이의 합
A   = 구간들 사이에 마른 틈이 존재하는지
```

부분 폭은 다음 접촉 계산의 폭과 시작 위치에 사용한다. 물량을 폭 값으로
대체하거나 physical diameter를 확대하지 않는다. 한 구간으로 표현할 수 없는
분리된 두 물 구역은 gap flag를 세운다. min/max만 남겨 그 사이를 젖은 것으로
만들면 안 된다. 현재는 그런 후보의 **시간 수송을 완료하지 못하며 전체 거부**한다.

이 부분 폭은 현재 **한 축의 기하 표현**이다. X 결과를 Y에 그대로 적용하면 안 된다.
2D 젖은 지지의 표현과 곡면 물리적 변형은 아직 구현하지 않았다.

## 4. GPU 전체 후보 수락과 유출

기존 ordered-map gate 뒤에 다음 단계를 추가했다.

1. 16×16 tile마다 map/certificate status와 gather의 support gap/범위를 검사한다.
2. GPU1×1 pass가 모든 tile과 이전 축 수락 flag를 합친다.
3. end/mean/support **세 bank 전체를 함께** 선택한다.
   거부 시 pre-contact 원본 세 bank가 bit-identical이다.
4. 유출/유출 운동량 소비자도 최종 flag와 이전 축 flag를 모두 사용한다.
   manual GPU loss probe로 두 bank의 유출을 검사했다.

접촉 후 이미 섞인 임시 운동량을 fallback으로 쓰지 않는다. 새 flag가
실패했는데 일부 runoff만 원장에 남기는 것도 금지한다. 별도 source가 경계 밖으로
나가려는 frame에 다른 recipient의 disjoint support가 발생하는 검사에서도
세 원본 bank/zero loss를 확인했다.

이것은 오프라인 **한 축 packet/support transaction**이다. 앱의 새 강우 source,
head debit, P4b event, 증발, 전체 simulation clock까지 연결한 transaction은 아니다.
입력 fixture 검증 일부도 CPU assert이며 production 입력 오류 처리가 완성된 것은 아니다.

## 5. 검증 결과와 해석

모든 HLSL은 **FXC ps_5_0 /Ges /WX + D3D11 WARP**에서 실행했다.

### 전면 접촉과 보존

source40:45, 정지 물100:105, 이동 속력1.8m/s, .5mm/cell 조건:

- .01초에는 접촉 전이라 자유 이동한다. 정지한 물이 미리 감속시키지 않는다.
- 1/60초에는60셀 자유 이동에 해당하는 접촉이 계산된다.
  양/음 방향 및 X/Y에서10개 패킷 그룹을 얻고, CPU map 오차는 약2.45e-6셀 이내다.
- 물량/부호 있는 end·mean 운동량 원장 검사를 통과했다.
- 과도한60개 압축 패킷은 status로 거부한다. 원본 end/mean 일치,
  loss0, recipient work0을 확인했다.
- 24개 row/192개 패킷의 서로 다른 질량·XYZ end/mean은 CPU 전체 run reference와
  map 약1.94e-5셀, momentum payload 약6.62e-8 이내로 일치한다.
  이 무작위 fixture에는 disjoint recipient도 있어 최종 publish는 거부된다.
  따라서 이 결과는 **후보 계산 일치**이며 모든 무작위 흐름의 시간 수송 통과가 아니다.
- 접촉 평균의 kinetic 지표가79.7608→61.2745로 감소한다. 단위는
  `mm³·m²/s²`이며 SI 에너지로는 `998.2e-9 kg/mm³`를 곱한다.
  비탄성 후보의 에너지 감소 확인이고 실제 바이저 에너지 검증은 아니다.

### 동일 시간 반복 접촉

같은 두 patch를.05초까지 힘 없이 이동시킨 뒤, CPU 한 번 계산한 유한 폭
접촉 profile과 비교했다. 예상 centroid162.5셀이다.

| profile 상대 L1 |30Hz|60Hz|144Hz|
|---|---:|---:|---:|
| 매번 셀 전체 폭으로 복원 |.000122%|.000122%|8.750122%|
| 부분 폭을 다음 갱신에 전달 |.000122%|.000122%|.000122%|

부분 폭 전달 조건에서 모든 step 수락/centroid162.5셀/물량·운동량 원장을 확인했다.
한정된 평면·고정 힘 후보의 사전 profile2%/centroid.01셀 허용치를 통과한 것이다.
30/60Hz는 이동이 grid에 맞는 특수성이 있다. 일반적인 물리 시간 수렴이나
variable-height/force/모든 접촉의 정확도를 증명한 결과는 아니다.

### 메쉬 지지와 장거리 이동

- X/Y에서 source의 run 끝에 반 셀만 남기는 경우와 전체 유출을 검사했다.
  부호 있는 end/mean momentum loss가 맞고, 한 셀 구멍 너머 다른 run에 물이
  재생성되지 않는다. packet 잔차 약7.46e-9 이내다.
- 완전히 젖은1024셀 row를±60.25셀 이동할 때 원장 검사를 통과한다.
  local source window 최대33, recipient source 검사16384회(한 bank 기준)다.
  end/mean/support 세 출력의 반복 작업과 접촉 PAVA 비용은 이 수에 포함하지 않는다.

## 6. 미채택 판정: 연속 수막에서 폭 보존 제약이 부적절

s91과 같은 실제 메쉬 합성100µm patch4251셀, old velocity0, 중력 및
local air(5,0,-10)m/s를 사용했다. **4251개 셀 모두** 큰 접촉 그룹 또는
certificate 불일치로 거부된다. 후보는 원본을 유지하고 loss0을 반환했다.
이 거부는 보존상 안전하지만 실제로 경과한 수송을 계산한 것이 아니다.

이미 연결된 액체가 흐르며 얇아지거나 두꺼워져야 할 때도 패킷의 축 폭을
보존시키면 큰 집단 접촉이 생긴다. local cap을 늘려 전체 row를 한 번에 섞는
것은 액체 압력/접촉선/점성 물리의 대안이 되지 않는다. 이 원형을 일반 film
solver로 **채택하지 않는다**. 수치 접촉과 부분 젖음/원본 복구 구현은 재사용한다.

## 7. 비용 평가

한 축의 분리된 steady-equivalent draw:

| 단계 |pass|
|---|---:|
| 현재 mean 재투영 |1|
| 두 축 packed occupancy leaf/group |2|
| local contact map+certificate / 검증 / 두 운동량 혼합 |3|
| ordered remap leaf/group/accept/gather |4|
| recipient support tile/accept/세 bank publish |3|
| 합 |13|

두 축과 SI predictor/packet/velocity commit까지 단순 합하면29패스다.
**2D support closure는 아직 없으므로 이는 비용 견적이며 완성된 두 축 solver의
실행 횟수가 아니다.** manual work/loss probe는 steady pass에 넣지 않았다.

1024×256, RGBA32에서 map+certificate는8MiB, end/mean/support gather 출력은
12MiB다. 최종 publish에도12MiB 출력이 필요하고, 이전 상태·임시 혼합 packet·
수락 전 출력이 동시에 필요하다. scratch aliasing 전 최종 순증은 확정하지 않는다.
local 배열33개와 주변 검색이 있어 pass 수만으로 연산이 가볍다고 볼 수 없다.

따라서 **저비용 runtime이라는 판정을 하지 않는다.** 실제 게임 GPU ms/FPS는
측정하지 않았으며 WARP 실행 시간으로 환산하지 않는다. 물리상 미채택인 후보를
큰 cap/추가 pass로 확장하는 데 최적화 비용을 쓰지 않는다.

## 8. 다음 구현 기준

다음 후보는 아래 조건을 함께 만족해야 한다.

1. 빈 공간의 전면은 부분 지지와 실제 이동을 유지한다.
2. 연속 수막은 폭을 강제로 고정하지 않고 **물량 보존 하의 축 압축/두께 변화**를 허용한다.
   접촉 전/후를 구분하며 먼 정지 물이 미리 제동을 전달하지 않는다.
3. 접촉 이후 운동량 결합과 pressure/contact-line closure를 명시한다.
   전체 wet row를 순간 평균하거나, 새 미정 계수를 물리 상수처럼 숨기지 않는다.
4. 한 recipient 안의 분리된 물 구역과 X/Y 지지를 표현하거나, 거부한 남은 시간을
   정확히 처리할 수 있는 경로가 필요하다. 단순 원본 유지로 시간을 통과시키지 않는다.
5. 먼저 이 단계의 반례/단독 접촉/실제 메쉬를 통과시킨 후 source/evaporation/
   P4b/clock atomic publish와 pass/storage 융합을 연결한다.

## 9. 전달

게임 runtime/튜닝/native material/geometry assets는 변경하지 않았다.
추가 사용자 게임 검사나 reload가 필요 없다. Git commit/push는 하지 않았다.

- `prototypes/s92/contact*.hlsl`: 접촉·부분 지지·GPU publish/loss gate.
- `tools/s92_contact_reference.py`: local GPU/전체 run CPU reference factory.
- `tools/check_s92_contact.py`: 접촉 전/후·양축/양방향·큰 그룹 거부.
- `tools/check_s92_reference_and_time.py`: 질량 가중 reference와 부분 폭의 반복 시간 검사.
- `tools/check_s92_support.py`: partial 폭/reference·분리 구간의 원본 복구.
- `tools/check_s92_boundary_loss.py`: run 경계 유출과 균일1024셀 장거리 이동.
- `tools/check_s92_dense_mesh.py`: 실제 메쉬의 일반 film 채택 반례·비용 견적.
- `diagnostics/2026-10-16/s92/*checks.json`, `delivery.json`, `source.diff`: 결과 및 보존 감사.
