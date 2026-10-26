# P0 continuous preview: deposit + drying 기본 경로

2026-10-25. 사용자 확인 위치는 **P0 → continuous physical RainFX preview**가 맞다.
새 독립 앱이나 checkbox를 추가하지 않고 이 경로의 실제 실행을 단순화했다.
앱 reload 후 UI에 `Mode: deposit + drying`이 표시된다.

## 실제3688 거부와 결정

사용자 실행은115.21875s 후 source288(재고 비교32 +새 누적 closure256)로 거부됐다.
입력 staging은0이며 앞선53frames의 일시적 부담은 회복됐다. 이번 직접 원인은
대기열 capacity가 아니다. frozen film/micro/heads의 유효성·체적·세대 연관을 확인했다.

|항목|X 운동량 /mm³m/s|
|---|---:|
|FP64 canonical leaf 합|3.6443747814|
|GPU source old-stock 합|3.6443748474|
|previous ledger stock|2.4980232716|
|ledger−source 차이|−1.1463515759|

물량은1130.2794mm³로 일치한다. 차이는 기존 운동량 bound0.3106879보다 크다.
현재 step closure는 통과하지만 이전 원장을 새 실제 stock에 연결할 때 실패한다.
작은 roundoff로 해석하거나 threshold를 넓힐 증거가 없다. 어느 과거 transaction에서
어떤 명령/합산이 차이를 만들었는지까지는 이 캡처로 입증하지 못했다.

이전 joint ledger는 source cumulative stock에 `flow end−flow initial`을 더했다.
최소 장면 방향에 따라 **선택적인 능동 film force/advection과 이 ledger delta 결합을
실제 제품 실행에서 제외**한다. 기존 알고리즘의 정확한 결함을 고쳤다고 주장하는 것이
아니라, 화면 필요성이 아직 입증되지 않은 의존성을 제거한 다른 제품 경로다.

## 남기는 동작과 근사

- 실제 입력, 가상 충돌/공급, SI 방울 운동, 경계 이탈, 같은 구간의 head→trail 전달.
- film/micro deposit과 최근 연결한 마름·micro→film 합류.
- 동일한 source 계산의 film·micro·head와 cumulative ledger를 함께 선택한다.
- film 자체는 제자리에 남는다. 물방울의 이동과 새 deposit이 물길을 만들며, film은
  증발·새 공급·micro 합류로 달라진다. 능동 sheet 유동/고임 반환/흡수는 없다.
- 정지 reservoir라는 근사와 일치하도록 남은 film 운동량은 surface/wall 전달에 기록하고
  film의 저장 운동량을0으로 만든다. 물·운동량을 조용히 버리지 않는다.

소스 거부·head/state 유효성·단위/시간·전역 물량 closure·prior receipt·resource lease
검사는 유지한다. 삭제된 flow의 성공 receipt를 가짜로 만들어 넣지 않는다. flow 검사를
참조하는 코드와 texture 자체를 제거하고, 새 실제 실행 경로의 source를 검사한다.
원인 미상의 기존288을 무조건 승인하는 변경이 아니다. source 오류가 있으면 여전히 거부한다.

## 비용 범위

실제31.25ms recipe의 정적 비교:

|항목|수송 포함|현재 기본|
|---|---:|---:|
|구간당 draws(audit 포함)|110|74|
|32Hz draws/s|3520|2368|
|그래프 canvases|96|87|
|audit32개 포함 자원 표시|128|119|
|그래프 descriptor|132.69MiB|84.59MiB|

readonly image·추가 광학·드라이버 할당은 별도다. 실제 CPU/GPU ms와 FPS는 미측정이다.
최초 metadata recipe 작성은 기존 코드를 재사용하므로 모든 CPU 준비까지 재작성/절감한
것은 아니다. 그러나 제외된 GPU명령/자원은 제출·할당하지 않으며 dangling flow 입력도 없다.

## 검증·적용·한계

네이티브10draws에서 source pinning/물량·운동량 closure, source ledger의 bitwise copy,
새 receipt의 승인·소스 거부·물량 생성·잘못된 dt 거부를 확인했다. 실제 변경 프로그램5종
strict compile 통과. 이전/현재 template 비교와 cache 재바인딩에서 flow36passes/9자원이
다시 나타나지 않으며 committed film은 checked source film을 읽는다.
제품13 groups, foreground7 cases, input recovery, field lifecycle14draws 및 closure
regression도 통과했다. 이들 local engine 서비스/일부 global context는 mock이므로 CSP
수분 실행 성공이나 전체 장면의 품질을 증명하지 않는다.

**기존 앱을 reload한 뒤 같은 P0 시작 버튼으로 사용한다.** 새 Mode 문구와119resources
(+optical snapshots)로 경로를 구분한다. 별도 장시간 시험은 요청하지 않는다.
기존 수송 프리뷰의 실패 자료/코드/캡슐은 보존하며 새 baseline 통과로 소급 처리하지 않는다.

현재는 목표 C/B의 기본 장면을 만드는 범위다. 강한 물보라 A의 능동 sheet까지 완성된
것이 아니다.32Hz의 위치 유지 표시와 head-only display scale 불일치도 아직 남는다.
다음 작업은 이 연속 표시·시각 연결이며 추가 정밀 수송 연구가 아니다.

증거: `diagnostics/2026-10-25/product_deposit_baseline/`.


## 후속 날씨 입력과 진단 정책

[현재 날씨 반응](RAINFX_WEATHER_RESPONSE_AND_DIAGNOSTICS.md)에 캡처 입력 표시와
누적 운동량만의 진단 분리를 기록한다. 현재 재고·단일 구간·물량 안전 검사는 유지하며,
119개 자원·74draws/구간은 변하지 않는다. 실제 CSP 적용과 장기 안정성은 미검증이다.
