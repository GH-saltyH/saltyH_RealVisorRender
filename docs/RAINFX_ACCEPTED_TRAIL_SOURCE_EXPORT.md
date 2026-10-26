# 승인된 트레일 원천 데이터를 실제 제품 경로에 보존

후속: [고해상도 광학 소비](RAINFX_FINE_TRAIL_PRODUCT_OPTICS.md)가 이제 P0 최종 출력에
연결되었다. source bin/summary 보존이 추가되어 아래 최초18MiB/4드로우 수치는
이전 단계 기록이며 현재4096방울은20.75MiB/6드로우다. 실제 게임 검증은 대기 중이다.

2026-10-25. **P0 continuous physical RainFX의 실제 실행 그래프에 연결했다.**
최근16구간의 선분과 해당 구간의 coarse 트레일 기여를 GPU에 보존한다.
새 세부 트레일을 화면에 그리는 소비 경로는 아직 연결하지 않았다.

## 품질과 메모리에 대한 판단 변경

사용자 지침에 따라 텍스처 점유를 줄이는 것보다 표시 품질을 우선한다. 세부 형상과
이력을 버리거나 기존 해상도에 억지로 맞추는 방식을 메모리 절감만으로 채택하지 않는다.
이번 고정 이력의 약18MiB는 확보한다. 메모리가 있다는 이유로 연산·대역폭·동기화가
무료라고 가정하지는 않는다. 최종 채택은 연결된 화면의 품질과 실제 프레임 비용으로
판정하며, 이전 작은 연구 메모리 상한은 최종 품질 목표가 아니다.

## 연결한 데이터

`rain_product_pipeline.lua`가 새 `rain_product_trail_export.lua`를 기존 물리/진단
wrapper 뒤에 설치한다. 실행기는 같은 패킷 제출 경로로 실제 내보내기를 수행한다.
새 앱/체크박스/별도 probe는 없으며 기존 P0 프리뷰 시작으로 동작한다.

묶음 하나에는 다음 세 텍스처를 보관한다.

|데이터|형식·크기|의미|
|---|---|---|
|geometry|RGBA32F, 방울 수×2|원래 source의 시작/끝 위치; 반올림하지 않은 metric 폭, 실제 전달량, serial|
|claim|R32F,1024×256|해당 구간의 트레일만 기존 raster 커널로 분배한 셀별 기여|
|marker|RGBA32F,1×1|승인된 serial·누적 물리 시간·dt·완료 표시|

16묶음은4096방울에서18.00024MiB,2048방울에서17.00024MiB다. 이는 추가 source
이력만의 용량이며 향후 고해상도 광학 출력/비닝/필터는 포함하지 않는다.
16은 첫 연결의 수명 범위이지 VRAM 때문에 정한 최종 품질 상한이 아니다. 장면에서
더 긴 세부 이력이 필요하면 고정 슬롯 수와 수명을 늘리는 방향을 먼저 평가한다.
자원 개수는 기존119개에서167개, 기존 optical snapshot4개까지 합치면171개다.

폭은 현재 source가 쓰는 preMeta 반경, 실제 du/dv와 교정 단위, shear widening에서
계산한다. 기존 정수 support에서 역산하지 않으므로 sub-cell 정보를 보존한다.
display gain을 원천 폭이나 물리 전달량에 넣지 않는다. 소비 단계에서 표시 gain을
따로 적용해야 한다. 반경/폭을 수정하여 물리 질량을 바꾸는 경로도 없다.

## 물량 분리와 시간 경계

기존 sparse gather의 정수 tent와 swept-line 적분을 재사용하되, incident film/micro
항을 제외하고 trail packet만 계산한다. source가 쓰는 검증된 coverage를 적용한다.
합쳐진 수막 총량의 차분을 트레일로 추정하지 않는다.

claim의 정확한 범위는 **coverage 이후, field evaporation 이전의 입력 트레일**이다.
이미 증발한 물의 실제 잔존 구성비를 추적하는 물리 원장이 아니다. 다음 표시 단계는
앞서 구현한 `min(현재 수막, 살아 있는 claim)` 예산과 수명 처리를 적용해야 한다.
현재 stock/per-step/질량 검사나 원장은 바꾸지 않는다.

joint receipt가 해당 serial에 승인된 경우에만 geometry/claim/marker를 쓴다.
슬롯을 덮기 전 marker를0으로 만들고, 두 텍스처를 쓴 **마지막에** marker를 게시한다.
첫 구간은 모든 marker를 초기화한다. warmup 이후 serial 재시작에도 같은 초기화를
적용한다. 거부된 구간의 내보내기는0이다.

고정16슬롯을 순환하므로 오래 실행해도 텍스처가 늘어나지 않는다. 실행기의
`visualInputs().trails`는 같은 소유 자원의 geometry/claim/marker 핸들을 내보낸다.
소비자는 marker가0이거나 다른 serial이면 coarse 표시로 돌아가야 한다.
이 검사는 기존 private ordered 제출 경로에 의존하며 일반적인 GPU completion
fence를 새로 증명한 것은 아니다.

## 비용과 검증

일반 구간은 invalidate→geometry→claim→marker의 **4드로우**가 추가된다.
32Hz이면 초당128드로우다. 첫 구간은 전체 marker 초기화 때문에19드로우가 추가된다.
추가 CPU readback은 없다. 매 구간18MiB 전체를 복사하는 방식도 아니다.
geometry는 두 줄, claim은 현재 구간의1024×256 sparse gather, marker는1픽셀이다.

드로우 수 증가율을 GPU 시간 증가율로 해석하지 않는다. 특히 추가 sparse gather는
방울 분포에 따라 비용이 달라진다. 실제 CSP/하드웨어 시간과 전체 FPS는 아직
측정하지 않았으며, 이번 단계에서2048/4096 기대 FPS를 새로 제시하지 않는다.

- 제품 회귀13그룹 통과. 실제 host→pipeline→executor 경로와 새 자원 수/핸들 노출을
  검사했다. engine/solver GPU는 mock이며 기존 optics8 WARP draws를 포함한다.
- 새 export는7 WARP draws/4 shader programs로 검사했다.1.3mm³의 incident 물을
  섞은 입력에서도 trail-only 기여는 독립 적분값.19140625mm³와 일치했다.
- 승인/거부, marker, 반올림하지 않은 폭, serial34까지의 슬롯 재사용을 확인했다.
- 내보내기를 제외한 기존 물리 패스의 shader/값/대상 목록은 추가 전과 동일했다.
  이것은 복사/연결 회귀 확인이지 새로운 고정밀 물리 채택 기준이 아니다.
- 실제 CSP 실행0회, 사용자 반복 실험 요청0회. 게임에 설치된 docs 경로의 모듈 hash는
  workspace와 대조한다. **게임 동작 통과**를 뜻하지 않는다.

## 사용자에게 보이는 상태와 다음 연결

앱 reload 후 같은 P0 메뉴에 `Trail source export:16 cohorts;18.00MiB;+4 draws/interval`
안내가 표시된다. 바로 아래에 fine trail optics는 아직 연결되지 않았다고 명시한다.
기존 화면이 새 가는 트레일로 바뀌었다고 기대하면 안 된다.

다음은 이 보존 데이터를 사용하는 광학 소비 경로다. 텍스처 바인딩 한도와 sparse
비닝을 이용해 실제 실행 비용을 제한하되, 메모리 점유만 줄이려고 품질을 낮추지 않는다.
세부 트레일/거친 수막의 이중 표시 방지와 같은 시점의 head 연결을 함께 확인한다.
데이터 연결만을 위한 별도 게임 시험은 요청하지 않는다.

도구: `docs/tools/check_trail_export.py`, `docs/tools/check_s282_product.py`.
결과: `docs/diagnostics/2026-10-25/trail_source_export/`.
