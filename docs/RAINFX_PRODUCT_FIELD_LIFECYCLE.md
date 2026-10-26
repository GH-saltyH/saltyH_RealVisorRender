# 통합 RainFX: 필드 마름과 micro→film 전환 복구

2026-10-25. 새 독립 앱/프리뷰가 아니라 기존 continuous physical RainFX에 연결했다.
물리 모델·실제 입력·기존 광학은 유지한다. 목표 영상 C/B를 가로막던 무기한 micro
누적을 먼저 줄이는 구현이며, 전체 최소 실행기 재구성이나 시각 품질 완료는 아니다.

## 동작과 입력

`rain_product_field.lua`가 기존 shared source-cell 갱신을 확장한다. 모든 status/totals/
commit은 같은 함수를 사용한다. 같은 계산 구간의 실제 weather-derived evaporation을
고정 입력 적분에서 받아, 셀의 실제 mm² 면적과 구간 시간으로 증발 체적을 구한다.
기존 설정 `RAIN_FILM_EVAP_DRY_UM_S`와 RH/온도/상대풍의 추정식은 바꾸지 않는다.
고습에서 빠르게 '닦여 보이는' 현상 전체를 증발만으로 만들지는 않는다.

micro 용량은 `area × RAIN_FILM_MICRO_JOIN_UM × (1+coating) /1000` mm³다.
기본20µm이면 bare20µm /coat40µm이며, 실측 재질 상수가 아닌 기존 교정 시작값이다.
초과 물을 film에 옮긴다. micro는 정지한 미해상 물이므로 film에 추가 운동량을
만들지 않는다. film의 체적은 늘고 기존 운동량은 유지되므로 혼합 후 속도는 달라진다.

그 뒤 film/micro 전체에 같은 증발 비율을 적용한다. film의 증발 물은 해당 물의
운동량도 가져가고, micro의 제거 운동량은0이다. 실제로 저장 가능한 감소량만 기록한다.
비가 오는 중에도 공급과 증발은 함께 계산하며, 강수가 끝나면 공급 없이 마름이 계속된다.
RH/온도 등의 입력은 근사 모델이며 이것이 실제 건조 시간의 보정 완료를 뜻하지 않는다.

## 물의 행선지와 수치 처리

- micro→film: 내부 이동이며 외부 공급·손실로 다시 세지 않는다.
- 물리적으로 표현 가능한 film 증가와 micro 감소가 같은 float32 체적일 때만 옮긴다.
  매우 작은 이동이 한쪽 저장 해상도 아래라면 양쪽을 그대로 둔다.
- 증발: 실제 저장 전후 차이의 물·운동량을 기존 evaporation row6에 합산한다.
  이제 이 행은 head **및 field** 증발이다. source raw-deposition/edge-cap 의미는 유지한다.
- 증발량이 저장 해상도 아래면 물/운동량을 모두 그대로 둔다.0질량 운동량 패킷을 만들지
  않는다. 물을 전부 잃으면 운동량도0으로 만든다.
- 기존 필름 수송·경계 유출·승인 게이트는 유지한다. 검사를 무조건 승인하지 않는다.

## 비용·바인딩

추가 pass/canvas/readback은0이다. source의 기존 셀 계산과 bank6 합산에 연산이
추가돼 GPU 계산 비용은0이 아니다. 실제 ms와 장면 품질은 미측정이다.

raw coating용 새 텍스처를 추가하는 첫 연결은14개 바인딩 한도에 걸렸다. 대신 기존
검증된 셀 adapter의 A에 `1+coat`를 저장하고 source cell에서1..2를 유효 범위로 읽는다.
R=면적, G=coverage, B=기존 validity1은 유지한다. 잘못된 raw coating은 adapter에서
거부한다. 이것은 제품 경로 내부 ABI 변경이며 다른 prototype/원본 source를 수정하지 않는다.
입력·출력 형식과 자원 수는 동일하다. 셀을 쓰는 status/totals/six commits 모두 함께 변경한다.

## 검증과 적용

네이티브14draws: bare/coat 합류, 마름0/부분/전체, 빈 셀, 표시 가능한 체적 이하의
합류·증발, 유효/무효 coating adapter, 실제 source totals·film/micro commit·단일/누적
원장 closure.8개 scalar 사례와 adapter, source 통합을 포함한다. 경계/전역 context는
작은 계산 fixture에서 분리되어 있으므로 실제 CSP 전체 통과로 부르지 않는다.

실제 제품 graph의 변경 셰이더4종이 `/WX /Ges` 컴파일을 통과했다.4개 연속 입력에
대해36개 pass instance가 변경되며 cache hit도 확인했다. 자원·pass·texture binding
수가 같고 최대14개 바인딩이다. 기존 product13 groups, foreground7 cases,
bounded-input recovery 및 closure parser regression도 통과했다.

공유 docs runtime 경로이므로 **메인 앱 reload 후 기존 continuous physical RainFX를
시작하면 적용된다.** P3 별도 checkbox나 새 진단 앱은 필요 없다. 새 시작은 기존처럼
dry state에서 시작한다. 이번 단계에서 별도 장시간 실행이나 조건별 로그는 요청하지 않는다.
현재 product UI에도 field drying/joining 활성 상태를 명시한다. 물리 설정 변경 시의
기존 reset 규칙을 지킨다.

실제 CSP 실행, 새 필드의 실제 GPU 시간, C/B/A 영상 유사도는 미검증이다.32Hz의
위치 유지 표시, head-only 표시 축소와 micro의 경로별 선명도는 아직 해결하지 않았다.
다음 구현의 우선순위는 연속 표시와 head/trail/film 표현 계약이며, 추가 수송 연구가 아니다.

증거: `diagnostics/2026-10-25/product_field/`.
