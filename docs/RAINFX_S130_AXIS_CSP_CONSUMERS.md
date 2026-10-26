# RainFX s130 — existing axis consumers on actual CSP

Date: 2026-10-18 (started 2026-10-17)
Status: ACTIVE — precise candidate fixes false admission refusal; exact analytic map gate remains open

## 1. 이번에 연결한 범위

기존 map → leaf/loss → group → admission/totals → full gather → end-only gather를
실제 CSP의 managed canvas dependency graph에 연결했다. 각 축을 동일한 초기
packet에서 독립 실행하고 separate logical texture 경로와 checked bank 경로를
비교한다. 아직 X 결과를 Y에 순차 전달하는 전체 step이나 live RainFX 재고가 아니다.

map/leaves/gather/endGather는 보존된 s109 strict compile source에서 추출했다.
별도 texture 본문을 복원한 뒤 s110의 원본4개 SHA256과 일치함을 확인했다.
group은 기존 본문, totals는 기존 txnCommon+본문을 유지한다. 원본을 가져오기 위해
과거 report를 다시 쓰는 renderer module을 import하지 않는다.

입력은13×7 격자의 합성 affine basis·dyadic volume/momentum, 하나의 dry cell,
full-domain run, dt다. 상태는 아래4개이며 모두 양 축/두 texture 경로에서 실행한다.

| 조건 | 목적 |
|---|---|
| moving |작은 일정 이동·부분 배수 |
| positive runoff |양 방향 큰 이동·배수 |
| negative runoff |음 방향 큰 이동·배수 |
| refused overtake |과도한 이웃 추월을 거부하고 입력/손실 유지 |

사용하지 않는 txn header symbol에는 dummy plan texture를 bind한다. consumer가
호출하지 않는 context 함수의 선언을 충족하기 위한 것이며, **live transaction header
검증을 통과했다는 뜻은 아니다.** s110 unchecked call-site specialization은 사용하지 않는다.

## 2. 비교와 독립 기준

- case당30개 RGBA32FLOAT target + scalar atlas1개;4개 case에서124개 accepted draw.
- atlas당30개 texture binding, 전체39,168개 float readback. 최대32개라는 SDK 한도 안이다.
- 4조건 ×2축 ×6개 consumer의 **48개 출력 쌍**을 float32 bit로 대조한다.
- seed6종도 독립 계산하며, 모두0인 잘못된 graph를 통과시키지 않는다.
- 일정 속도 map은 독립적으로 계산한 affine 이동량과 비교한다.
- End/Mean의4개 성분은 gather+runoff 수지를 확인한다. 부동소수점 합산 기준은
  `64 × float32 epsilon × sum(abs(input component))`이며 실제 오차를 함께 기록한다.
  branch 간 bit 비교나 affine map의 정확 일치 기준은 이 수지 허용 오차와 별개다.
- full gather의 End와 end-only gather는 bit 단위로 같아야 한다. 거부 시에는
  End/Mean 입력을 유지하고 runoff가0이어야 한다.

로그9자리 유효숫자는 float32로 다시 round-trip한 뒤 비교한다. 이는 실제 R32FLOAT
값을 복원하는 과정이며 반올림 오차를 감추기 위한 비교 허용 오차가 아니다.

## 3. 원본의 실제 결과 — bank 문제와 수치 문제를 구분

WARP에서는124개 draw,48개 출력 쌍, 이동·수지·거부 기준이 모두 통과했다.
사용자가 실제 CSP에서 실행한 원본에서도 **48개 출력 쌍은 모두 bit 단위 일치**하고
모든 seed control이 일치한다. 그러나 독립 물리/수치 기준은 전체 통과가 아니다.

| 실제 CSP 조건 | X admission | Y admission | 독립 기준 |
|---|---|---|---|
| moving |허용 |허용 |통과 |
| positive runoff |허용 |거부(status2) |실패 |
| negative runoff |허용 |거부(status2) |실패 |
| refused overtake |거부 |거부 |통과 |

정상 일정 이동이어야 할 runoff map에서 최대 **4.76837158203125e-7 cell**의 차이가
발생했다. Y의 인접 map 경계가 양 방향7곳, 음 방향15곳에서 그 크기만큼 겹친다.
map 자체의 status는0이지만 leaf의 `l < last` 검사가 status2를 만들어 전체 배수를
거부한다. 두 texture 경로가 똑같이 실패하므로 bank 주소만의 문제는 아니다.

이 기록을 통과한 결과로 고치지 않는다. 원본 앱·package·WARP 자료·CSP 원문과
`actual_observation.json`은 stage 루트에 보존했다. 특정 GPU/compiler 내부 명령을
확인한 것은 아니므로 FMA나 reciprocal을 단일 원인으로 확정하지 않는다.

## 4. 별도 v2 precision 후보

기존 계산식을 유지하면서 map의 projected speed, face의 두 곱·합·분모·나눗셈,
양 endpoint 계산에 HLSL `precise`를 적용한다. 공유 면 계산을 재결합하거나 일부
곱/합을 합치는 최적화를 제한하는 후보이며, 물리 계수/판정 threshold는 바꾸지 않는다.
검사에서 허용 오차를 넓히거나 작은 겹침을 무조건 무시하지 않는다.

추가 pass, target, texture fetch는 없다. 제약에 따른 실제 shader instruction/GPU 시간
비용은 아직 측정하지 않았다. 이 후보는 생산 shader에 적용하지 않았다.
후보도 WARP124개 draw와 같은 엄격 기준, lifecycle16개, decoder14개를 통과했다.

사용자가 v2를 실제 CSP에서 실행했다. 39,168개 값과48개 logical/bank 출력 쌍을
다시 수집했으며, 모든 seed와 branch bit 비교가 일치한다. 정상3조건의 두 축 모두
admission을 허용하고, 의도한 추월 조건은 계속 거부한다. Y 공유 경계의 겹침은
양·음 방향 모두 **0곳**으로 줄었다. End/Mean 수지·full/end-only 일치·거부 시
입력 유지도 전부 통과한다.

그러나 큰 이동의 map과 이상적인 affine 기준값 사이 최대4.76837158203125e-7 cell
차이는 남았다. **변경하지 않은 strict parser의 `allPassed`는 v2에서도 false다.**
따라서 shared-face 거부 문제가 제거됐다는 판정과, 모든 수치 gate가 통과했다는
판정은 구분한다. source/helper equivalence와 admission 개선만 확인했으며,
정확한 내부 compiler 명령 원인이나 일반 수치 오차 한계를 확정하지 않았다.

원본과 v2 총78,336개 실제 float를 보존한다. 입력 성분 합산의 최대 실제 오차는
정해 둔 roundoff 한도의 약0.21% 이하였으며, 이 수지 한도로 map의 exact 기준을
대체하지 않았다. 생산 모델 채택 전에 곡면·순차 축에서 수치 오차를 계량해야 한다.

## 5. 실행·보존 자료

원본 앱은 `realvisor_s130_axis`, 후보는 `realvisor_s130_axis_v2`라는 별도 폴더다.
각각6개 파일이며 기본 OFF·load당 one-shot이다. 다른 module 이름과 cache key를
사용하고 기존 앱을 덮어쓰지 않는다. 동일 source/schema는12개 shader cache를 공유한다.

명목 texel payload는 **313,344 bytes/앱**이다. 실제 peak memory·GPU/CPU 시간·FPS는
측정하지 않았다. 제출한 canvas를 임의 프레임 지연으로 retire하지 않으며 strict
completion은 false다. 일반 GPU 완료/queue gate는 이 readback으로 풀지 않는다.

`docs/diagnostics/2026-10-17/s130/`은17일 시작한 작업의 보존 경로다.

- 루트: 원본 `source_freeze.json`, layout, WARP·CSP 결과와 설치/로그 provenance.
- `v2/`: precision 변환과 별도 package·검사·설치/로그 provenance.
- `axis_checks.json`: WARP124 draw,12 synthetic strict compiles,16 mocked lifecycle,
  14 decoder control. 각 앱의 guarded installer scratch9개도 별도 기록한다.
- `delivery.json`, `source.diff`: 최종 결과와 보존 감사.

생산 runtime53개, root INI3개, s91–s129 소스374개와 이전 결과/asset을 보존한다.
게임 물리는 s87, 진단은 s89 상태이며 commit/push는 하지 않는다.

## 6. 다음 단계

다음은 남은 이상적 affine 기준과의 수치 차이를 계량하고 실제 곡면 metric,
sparse boundary/run, X→Y 순차 결과 전달에서 오차·admission을 검증하는 작업이다.
live source/stock 소유권과 목표 비용도 남는다. 이번 affine consumer 비교나
false-refusal 개선을 전체 물리 정확도·strict analytic gate·성능 달성으로 확대하지 않는다.
