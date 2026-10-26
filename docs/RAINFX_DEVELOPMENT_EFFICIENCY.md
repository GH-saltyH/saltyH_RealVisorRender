# RainFX 개발 비용·이익 추적

**2026-10-25 재계획:** [제품 범위·낭비 평가](RAINFX_PRODUCT_REFOCUS_2026-10-25.md).
기존 s282–s283 합계2.75–6h 및 개별 수송 연구의 잔여 일정은 현재 계획으로 사용하지
않는다. 새 우선순위는 최소 실제 장면 경로이며,60–120분의 첫 구현 상한 뒤 연결된
코드를 제시하거나 범위를 줄인다. 전체 완성 일정은 장면·비용 증거가 없어 미확정이다.

2026-10-24부터 적용. 기록 파일: [work_ledger.json](development/work_ledger.json).
시간은 사용자 대기와 일정 간격을 제외한 개발 작업량 추정이다. 정확한 납기나 FPS 약속이 아니다.
현재 추정은 아직 완료되지 않은 엔진 연결·광학 소비 경로 때문에 신뢰도가 낮거나 중간이다.

## 운영 방법

- 시작할 때 목표 이익, 작업시간 범위, 불확실성, 필요한 설계 접근/사용자 시험 예산을 기록한다.
- 끝날 때 측정 구간과 미측정 구간, 로컬/게임 실행 횟수, 얻은 증거, 남은 위험을 기록한다.
- 같은 문제에 실질적으로 다른 접근이2회 실패하거나 예상 상한을 넘어 이익이 없으면,
  새 실험 단계를 늘리지 않고 단순화·대체·범위 재조정을 선택한다.
- 로컬 테스트의 fixture 수정과 제품 설계 변경을 구분한다. 실행 횟수와 성공률을 숨기지 않는다.
- 새 사용자 시험은 화면 산출 또는 실제 제품의 필수 안전 문제와 연결한다. 기존 증거는 재사용한다.
- 별도의 계측 프레임워크를 만들지 않고 기존 결과와 이 추적표를 갱신한다.

## s280 기록

|항목|s280 결과|
|---|---|
|제품 이익|렌더 FPS와 독립적인 시간·선형 입력 누적 기반. 실제 처리량 개선은 미측정|
|실측 구간|구현·로컬검증13분06초 + 문서·추적 정리. 측정 합계 약19.7분; 초기 검토는 미측정|
|원래 예상치|추적 시작 전 값은 없으므로 소급해서 만들지 않음|
|설계 접근 / 실질 보정|1 /1. 실제 경계와 정수 solver clock을 분리하고 기본32Hz 선택|
|로컬 실행|5회: 통과2회, 실패3회. 그중 fixture 보정2건|
|사용자 게임 / GPU 진단|0 /0|
|현재 상태|새 모듈 로컬 검증 완료. 엔진·GPU·광학에는 미연결|

s269–s278에서 명시된 게임 세션은 최소13회다. 당시 개발 경과 시간은 정확히 기록되지
않아 합산하지 않는다. 새 추적이 과거 비용을 정확히 측정한 것처럼 표시하지 않는다.

## s281 기록

- 실제 캡처 코드→고정 구간 입력→기존 실행기를 제품 팩토리로 연결.
- 최초 추정45–120분, 측정 약45.2분. 분석·구현·검증·문서화 포함, 사용자 대기0.
- 접근2개 중 단순 중간시점 소스안1개는 밀도·풍속 상관 문제 때문에 시험 전에 교체.
- 로컬 실행3회 모두 통과, 사용자 게임0회, GPU 진단/셰이더 재컴파일0회.
- 엔진 API/GPU는 모의 서비스로 검증했다. 실제 게임의 메인 활성화·광학은 아직 남음.
- 다음은 렌더러가 재사용된 오래된 CPU 승인 bank를 읽지 않도록 GPU 커밋을 소비하는 작업.

## 남은 작업의 초기 추정

|단계|예상 작업량|예상 이익|추정 신뢰도 / 시험 예산|
|---|---|---|---|
|s282 커밋 상태→기존 광학 연결|45–120분|첫 실용 화면 후보, head/trail/film 동시 평가|낮음~중간 / 묶음 게임 평가1회|
|s283 필수 상호작용·2048/4096 평가|120–240분|병합·pool·크기 동작 완성과 채택 판단|낮음 / 대표 평가1회 뒤 재판단|

남은 s282–s283 합계2.75–6시간은 현재의 **작업량 가늠**이며 완성 기한이 아니다. 각 단계가 끝날 때 실제
시간과 미해결 항목으로 다시 계산한다. 추가 CSP 이슈가 나오면 자동으로 연구 범위를
확대하지 않고, 이미 확인된 방식으로 단순화할 수 있는지 먼저 판단한다.


## s282 기록

- GPU 커밋 영수증으로 선택한 방울·수막을 기존 광학에 연결하고, 기본 OFF 연속 프리뷰를 메인 메뉴에 추가.
- 최초 추정45–120분, 측정 50.9분. 사용자 대기0; 분석·구현·로컬 검증·문서·봉인 포함.
- 설계 접근1개. 로컬 검사8회 중 통과4·실패4; 실패는 기대 반경식/이미지 경로/SDK 상수 fixture 보정과 진단 재시도였다.
- 최종12개 로컬 그룹 통과. 새 광학3종 엄격 컴파일, 완주 검사당 WARP8draws. 실제 CSP/GPU 시간·FPS 측정0.
- 사용자에게 요청한 것은 화면이 나오는 연속 후보의 묶음 평가1회이며 아직 결과 없음. 추가 비가시 진단 요청0.
- 새 광학 복사본은4개 재사용 타깃, 프레임당4draws, 추가 CPU readback0. 실제 전체 앱 비용은 미측정.
- 다음 결정: 실화면에서 구체적인 장애가 없으면 필수 병합/pool 상호작용과2048/4096 채택 평가로 진행.

### s282 첫 실제 진입 수정

첫 사용자 실행1회는 GPU 할당 전 clock 타입 검사에서 실패했다. 기존 s245의 cdata
래퍼 누락을 복구했다. 실제 cdata 콜백을 쓴 회귀 검사 추가 후 로컬9회 중5회 통과
(기존 fixture 실패4회). 물리/허용오차 변경0, 새 진단0; 같은 세션에서 메인 앱 reload로
시각 후보를 재시도한다. 실제 화면·실시간 통과로 계산하지 않는다.


## s282 연속 실행 거부 수정

- 최초 예상20–45분, 측정 24.7분. 실제326번 거부 자료에서 source mask32를 확인.
- 물량 차이0, 상쇄된 운동량 차이7.45e-9의 기준 과민성에 한정해 수정. 새 물리/유체 모델 없음.
- 설계 접근1개, 로컬3회 모두 통과. 실제 수정 프로그램2종 엄격 컴파일, WARP 경계 검사4draws.
- 입력 받은 실제 보고2건(최초160은 사유 미보존, 추가326은 보존됨). 추가 상세 실행1회 후,
  원인 수정 후보의 가시 실행 재검증1회만 요청했다. 새 독립 진단0, 추가 GPU draw/readback0.
- 실제 수정 통과/전체 성능은 아직 미측정. 다음 실패가 있으면 보존된 원인부터 읽고,
  다른 허용오차를 자동으로 넓히거나 조건별 연구 과제를 추가하지 않는다.


## s282 입력 backpressure 복구

- 최초 예상30–60분, 측정 30.5분. 실제 약6분 광학/11618구간 통과 보고 뒤 admission 한도 중단을 분리.
- 같은 고정 대기열에200ms 입력을 넣으면 기존 코드가 종료하는 것을 재현. 별도 bounded CPU 입력 보관·순서 재시도 구현.
- 설계 접근1개.250ms 경계 검사에서0.25s 보관 초안의 한계1건을 잡고, 후속 입력 여유를 포함한16프레임/0.5s로 확정.
- 로컬8회: 통과7·실패1. GPU 물리 코드/패스·자원/읽기 추가0; 일반13그룹과 burst/Stop/지속 정체 검사 통과.
- 새 사용자 실행 요청0. 실제 새 복구·FPS는 미검증이며, 다음 일반 사용의 자동 보고로 평가한다.
- 정상 시 보관 큐는 비어 있고, 지속 처리 부족은 한도로 종료한다. 시간을 버리거나 무제한 backlog로 숨기지 않는다.

## s282 background suspension delivery

- Expected30–60min; elapsed wall interval is in the ledger and exceeded the estimate.
  Context/tool scheduling was not measured independently; do not call all elapsed time active engineering.
- One foreground pause approach implemented. Seven transition cases passed with engine/GPU mocked;
  product and bounded-input regressions passed. No new user game run requested.
- No extra solver GPU resources; existing128 are reused. Resume repeats20 CPU asset hash checks.
- Earlier stock investigation reached its budget: actual native capsule verified, but native source
  replay hit a different guard. Source64/288 remains unresolved; no speculative tolerance widening.
- Next bounded work: inspect the expanded existing audit from an ordinary failure, repair a concrete
  source closure defect if supported, then qualify visible output and required interactions.

## s282 source closure triage

- Classified necessary work in RAINFX_REQUIRED_NEXT_WORK.md: sustained source correctness first, CSP return, visible consistency, interactions, then whole-product cost.
- One offline classification approach, two local runs passed11 cases. No new GPU program, acceptance change, resource or dedicated user experiment.
- Actual1732/10170 archives lack failed-step totals; cause and repair remain unproven. Existing extended audit will be used on ordinary failure.
- Implementation interval is in the ledger; initial source review before that record was unmeasured. Next source repair is bounded30-45min with one reproduction approach before replanning.

## s282 deposition cancellation (2026-10-25)

- Actual12810 identifies mask8: equal water, nonzero Z momentum remainder; all closure gates pass. Native stock validates.
- One absolute-term scaling amendment; existing total row10 reused, no added GPU passes/resources/readbacks. Extra logical raster reads8MiB/step; GPU time unmeasured.
- Eight local checker runs passed;36 native draws and3 strict production shader programs. No dedicated game experiment requested.
- Forecast25-45min; tracked implementation interval is in the ledger. Initial diagnosis before that record is unmeasured.
- Original leaf gross unavailable: native captured-tail test uses explicitly synthetic cancelling packets. Actual CSP fix and earlier64/288 remain unverified. Stop numerical research pending ordinary feedback.

## s282 head4592 bounded travel (2026-10-25)

- Actual frozen slot and captured force inputs reproduce trace128-step exhaustion and transition3 in a focused native fixture. Context is stubbed; original CSP post-force texture was unavailable.
- One bounded-game approximation: retain last supported endpoint and water, allow fast-head under-travel. No added iteration, pass or resource.
- Forecast20-40min; measured implementation interval is in the ledger, initial review unmeasured. Seven checker invocations:6 passed,1 temporary loaded-DLL cleanup failure after the native arithmetic completed. Total37 native draws across focused/repeated and optical regressions; no dedicated user run requested.
- Actual CSP success and original exact transition predicate remain unproven. No more trace study before ordinary preview feedback.

## Preview visual contract audit (2026-10-25)

- User requested a component/visual scope description; no new probe, native GPU execution or game test. SI model retained.
- Code audit identifies head-only appearance gain,32Hz zero-order visual hold, separate field motion and omitted old-P3 field evaporation/micro conversion in s282. Existing4592 stock shows645.29mm3 film and3543.98mm3 micro.
- These are integration/quality limitations, not proof of final visual adequacy. Next minimum scene must restore drying, continuous display and a consistent appearance-scale contract. Engineering elapsed time was not measured independently.

## Integrated field lifecycle implementation (2026-10-25)

- Existing continuous path now uses captured evaporation and configured micro height/coating for field drying and internal joining. Same source/commit/totals; no new preview, pass, canvas or readback.
- First extra texture hit the14-binding cap; coating now travels in the existing validated cell channel. No topology growth.
- Forecast35-70min; tracked implementation interval is in the ledger, initial review unmeasured. Nine local checker invocations:7 passed,2 failed (one implementation binding issue, one missing fixture declaration),52 native draws across runs. Final focused check14draws and4 strict production programs; no user game run requested.
- Actual CSP/scene quality and incremental GPU time are pending. This restores a missing process and is not the full reduced execution-path redesign;32Hz display and head/film appearance scale still need work.

## Deposit+drying product baseline after actual3688 (2026-10-25)

- Canonical source and water agree; prior ledger X differs by1.146, exceeding its existing0.311 budget. No tiny-roundoff claim or tolerance widening. Exact historical corrupting command remains unproven.
- In accordance with refocus, remove optional active film transport and its ledger delta; pin remaining film momentum to the surface with bookkeeping. Existing source/state/time checks remain. No new app/checkbox.
- One implementation approach; forecast40-80min, tracked interval in ledger (initial review unmeasured). Nine check invocations:8 pass,1 mock receipt-key fixture failure.40 native draws total; changed production programs5 strict-compiled. No dedicated user run requested.
- Recurrent110->74draws/interval,132.69->84.59MiB graph descriptors,128->119owned canvases including audit slots. Actual frame-time improvement and CSP stability remain unmeasured.
- Next work is render continuity/appearance, not renewed exact film-transport research.


## Weather observability and cumulative-only diagnostic separation (2026-10-25)

- One scoped implementation, forecast25–50min; measured interval in ledger excludes initial unmeasured inspection. Six checker invocations passed;29 native draws across runs and3 changed production programs strict-compiled. No new user run requested.
- Actual12343 current stock/per-step checks pass; historical momentum residual crosses a shrinking net-term bound. Keep residual/mask as notice; current stock, per-step momentum, all water/state/time checks remain hard. Previous actual3688 still rejects. No pass/resource/readback increase.
- Live captured-weather UI separates actual engine input from missing effect connections. Rain/wind are connected, RH/T mainly dry slowly; track wetness/water do not directly supply visor spray. Weather mock/header checks are not CSP visual proof.
- Next remains continuous displayed motion/coherent appearance and actual scene response; no new precision probe series.
