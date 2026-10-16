# RainFX s86 — P4b 국소 고임→P1 방울 보존 전환

Date: 2026-10-15. Status: ACTIVE — a23527e에서 이어 실제 P2/P3 파이프라인에 P4b 연결. Production GPU/Lua/광학 회귀 검증 통과. **실제 게임의 비용·고임 분류·수송 시간 개선은 검증 대기.**

## 1. 기준과 사용법

사용자가 s85 상태를 `a23527e`로 스탬프한 clean tree에서 시작했다.
변경 전 Lua/HLSL/문서는 `diagnostics/2026-10-15/s86/baseline`에 보존했다.
기존 물리·날씨·표시 크기·E2/E3/G-force/재질 튜닝은 보존한다.
이번 변경은 **국소 고임의 표현을 수막에서 기존 P1 방울로 옮기는 것**이다.
연속 수막의 압력·관성 solver를 완성한 단계는 아니다.

앱 **reload 필요**. RainFX → Weather inputs and physical units (P0):

1. P1 SI motion, P2 physical birth, P3 conserved film, P4 conservative transport를 켠다.
2. `Enable P4b localized pool return (resets water)`를 켠다.
3. 정상 광학은 기존 view0, 수막 두께는 view1이다.
4. 새 view4는 **마지막 게시 step의 전환 위치/높이**를 보라색으로 표시한다.
   누적 field나 새로운 물 재고가 아니며, 드문 전환은 순간적으로만 보인다.
5. `Log P3 actual water budget`은 같은 frame의 원장+P4 현재 field 추정을 출력한다.
   원장에 `transport=P4b poolReturned=...`가 추가된다.

새 키는 `RAIN_PHYSICS_P4_POOL_PREVIEW=false` 하나다. 기본 OFF다.
P4b/P4/P3/P2/P1 토글은 전체 source·head·field 재고와 시계를 초기화한다.
P4 또는 P3가 꺼지면 P4b는 동작하지 않는다. P4b OFF/ON 비용 비교는
**같은 리플레이 시점과 같은 초기화 후 누적 시간**에서 해야 한다.
GPU heads/lifecycle mode3 또는6의 기존 P1/P2 조건도 유지한다.

## 2. 후보와 슬롯 배정

`rainFilmPoolCandidate.hlsl`은 1024×256 field를16×16 region1024개로 나누고
각 region의 가장 높은 full-coverage 셀 하나만 조사한다.
네 이웃의 최대 높이를 background로 남기고 초과량을 요청한다.
float32 셀이 실제 잃을 수 있는 체적을 record에 저장한다.

다음 조건을 모두 만족해야 후보가 된다.

- supported/full-coverage 셀이며 네 이웃도 supported/full-coverage;
- 초과 물량의 등가 구 직경이 기존 persistent-head 최소값 이상;
- 초과 높이가 같은 물량과 현재 접촉각의 spherical-cap 높이보다 큼;
- 그 cap의 물리 footprint가 현재 셀 면적보다 넓음.

최소값은 `RAIN_BIRTH_MIN_PERSISTENT_MM`를 공유한다. 이는 persistent head로
보낼 최소 표현 체적의 등가 직경 조건이며, 표면 물의 실제 최소 존재 크기는 아니다.
display gain, optical gain, 화면 텍셀 크기는 이 판단에 들어가지 않는다.
partial boundary, uniform sheet, 연결된 평평한 ridge, 얇은 trail은 유지한다.
최고점이 거절되면 같은 region의 다른 점까지 무제한 탐색하지 않는다.

`rainFilmPoolAddress.hlsl`의 region↔slot 매핑은 한 프레임에 일대일이다.
슬롯이 region보다 많으면 한 slot group씩 순환하고, **group을 모두 돈 뒤**
region 회전을 한 칸 진행한다. `tick % regionCount`를 group 선택과 함께 쓰면
4096슬롯에서 특정 빈 슬롯이 일부 region만 반복해 맡는 aliasing이 생겼다.
고친 매핑에서는 그 슬롯도4096 published step 안에1024 region 모두를 방문한다.
전체 후보가 매 프레임 모든 빈 슬롯을 검색하는 구조는 아니다.

## 3. P2/P3의 원자적 연결

새 런타임 Lua 모듈이나 새 SDK API는 추가하지 않았다.

1. P2가 **이전 게시 field**로 후보 pass를 실행한다. 초기화·resize 직후에는
   유효 field가 없으므로 후보0으로 시작한다. speculative write field는 읽지 않는다.
2. 기존 P2 event를 P4b일 때만4행→5행으로 확장한다.
3. 원래 rain attached birth가 없고, 배정 슬롯이 status0/volume0일 때만 고임을 받는다.
   비가 그친 상태에서도 고임 복귀는 가능하다. 슬롯이 없으면 물은 field에 남는다.
4. event0행은 새 head 위치/체적/generation tag를 기록한다. 기존 state/meta의
   generation handshake를 그대로 사용하므로 같은 event가 재생되지 않는다.
5. event4행은 **원래 빗물 충돌 위치.xy + 내부 복귀 체적.z**다.
   P3 descriptor는 이 원래 위치에 rain film/micro를 놓는다.
   고임 head 위치로 rain source를 끌고 가지 않는다. rain beta/Weber도 유지한다.
6. `rainFilmPoolAvailable.hlsl`을 donor flux와 field resolve가 공유한다.
   둘 다 같은 event를 읽고 head에 넘긴 물을 먼저 차감하여 이중 수송을 막는다.
7. corrected head meta/source 총계/field/optics/tick을 기존 publication 경로에서
   함께 확정한다.13개 shader 지점 중 하나가 pending이면 모든 read bank와 시계는
   이전 값이다. dispose/reset은 후보/이벤트/field의 상호 texture 참조도 해제한다.

고임의 과거 운동량은 기존 field에 저장되어 있지 않다. 복귀한 head는
**정지 속도에서 시작**하고 다음 step부터 기존 P1 힘/관성/고착을 적용한다.
이는 이번 bounded closure의 한계다. 수치적으로 과대한 준정상 속도를
초기 속도로 복사하지 않으며 운동량 보존까지 주장하지 않는다.

## 4. 원장과 진단

P2 reserve는 누계다. 따라서 film→head 복귀를 head에만 더하면 P2 잔고가
틀어진다. 기존 extra-total spare W에 `poolReturned`를 Kahan 누적한다.
추가 budget canvas는 필요 없다.

```text
P2:
input + cumulativePoolReturn = grossFilmReserve + microReserve + bounce
    + capacityReserve + exit + currentDrops + headEvap

P3:
input = currentFilm + currentMicro + currentDrops + bounce + exit
    + headEvap + fieldEvap + runoff
```

P3의 `poolReturned`는 내부 이력이며 외부 공급/손실로 더하거나 빼지 않는다.
manual16-float snapshot의 기존 spare 채널을 사용한다.
P4 current-field Courant 진단은 **pool debit을 비활성화**한 별도 values를 사용한다.
이미 복귀를 차감한 field를 또 차감하거나, 다음 step의 speculative event를
섞어 속도를 과소평가하지 않는다.

optics texture의 R/G는 기존 물리 film/micro µm 그대로다. 비어 있던 B에
마지막 step의 복귀량을 높이로 환산해 기록한다. 일반 광학은 R/G만 사용한다.
view4에도 기존 native occlusion을 적용한다. 초기 디버그 분기의 FXC X4000은
분기 내 early-return을 없애 해결했고 최종 full shader가 /WX를 통과했다.

## 5. 비용

- 추가 steady pass **1개**: `RealVisor/P4b pool candidates`.
- candidate1024×1 RGBA32F =16KiB.
- event 추가1행 =16×slotCount bytes.4096슬롯이면64KiB.
- 합계 payload **16KiB +16×slotCount bytes**,4096슬롯에서80KiB.
- 기존 P2 event 출력 픽셀25% 증가, flux/resolve/optics에 event 조회/배정 계산 추가.
- CPU 방울 loop, steady GPU readback, draw call, 물리 field 해상도 증가는 없다.
- payload는 driver allocation/캐시/컴파일 비용을 포함하지 않는다. 실제 GPU ms는
  아직 측정하지 않았으며 FPS 개선을 보증하는 수치가 아니다.

후보 탐색은262144셀의 field/metric 읽기와 region별 이웃 검사로 고정한다.
P4b OFF에서는 후보 canvas/pass가 없고 event도 기존4행이다.

## 6. 로컬 검증

모든 GPU 실행은 FXC ps_5_0 **/Ges /WX**, D3D11 WARP다.

| 도구 | 확인 |
|---|---|
| `tools/check_s86_pool_gpu.py` | 실제 source→P1 state/meta→P3 descriptor/paired meta→flux/field/optics→P2/P3 budget의8개 gate. 비가 없는 복귀·rain source 위치 독립·generation·슬롯1..4096·분류·OFF 동등·8회 연속 보존 |
| `tools/check_s86_pool_binding.py` | 실제 Lua/main의13개 pending 지점+예외, 이전 field만 참조, tick 일치, 수동 진단 격리, 두 로그의 내부 원장, resize, stale callback,40회 토글. live bank P4=17/P4b=18/reset=0 |
| `tools/check_s86_pool_realmesh.py` | 실제 메쉬/마스크/area, 제공된 두 peak 셀의 물량을 넣은 **합성 field**에서2개 head 복귀. 실제 게임의 주변 분포를 복원한 시험은 아님 |
| `tools/check_s86_birth_off.py` | sparse/rain/overflow/occupied/micro/wet/normal의8개 P4b OFF event가 a23527e와 bit-identical |
| `tools/check_s86_pool_lens.py` | 전체 렌더 shader 경고 없음. 물리 굴절·empty/native/depth 기존 gate, view4 표시, marker가 정상 optics를 바꾸지 않음 |
| `tools/check_s86_pool_regression.py` | 기존 P3 GPU13/P4 GPU9 수치 회귀 gate 통과. source composer를 생산 Lua와 같은 새 header 연결로 갱신 |

새 내부 전환을 포함한 no-rain 첫 원장 잔차는 P2=0/P3≈−2.66e−7mm³,
rain film 동시 입력은 약−1.72e−5/−1.79e−5mm³다.
8회 닫힌 연속 step의 절대 잔차는 약2.93e−7mm³ 이하다.
단기간 fixture 결과이며 장시간 float32 누계 gate를 대신하지 않는다.
`diagnostics/2026-10-15/s86/`에 결과와 source.diff/해시를 보존한다.

## 7. 게임 검토와 남은 범위

**이번 빌드는 보존적 전환의 검토용이다. P4 수송 시간 gate는 아직 열려 있다.**
넓은 고임·연결된 리뷸릿·부분 셀은 분류 조건상 film에 남고, 슬롯 부족이나
높은 이웃 background 때문에 복귀가 제한될 수 있다. 이 경우에도 기존 CFL
제한은 유지된다. 별도의 압력/관성 수송 개선은 그 잔여 분포를 보고 결정한다.

같은 낮60% 조건에서 충분히 누적시킨 뒤, 정차와137km/h 각각 한 번의
`Log P3 actual water budget` 쌍으로 다음을 확인한다.

- `transport=P4b`와 증가하는 `poolReturned`, 원장 residual;
- 제한 film 질량 비중/속도 보존율과 과도한 최대 두께의 변화;
- 고임에서 나온 head의 위치/크기/흐름, head–trail 연결의 갑작스러운 튐;
- 같은 리플레이/누적 시간에서 P4b OFF/ON FPS·Memory.

view4의 순간 marker가 항상 유지될 필요는 없다. 누계가0이면 방울 수를 강제로
늘리거나 물리 직경을 변경하지 말고 분류/슬롯 제약을 우선 확인한다.
이번에 사용자의 기존 빗방울 크기·display 계수·Smear/legacy local film 정책은 바꾸지 않았다.
