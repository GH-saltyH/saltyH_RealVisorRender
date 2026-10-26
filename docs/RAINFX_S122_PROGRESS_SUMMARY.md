# RainFX 재설계 — 현재 위치·측정 지표·남은 로드맵

2026-10-17. **Status: ACTIVE — s122 시점의 통합 요약.**

## 1. 현재 어디까지 연결됐는가

게임의 물리 구현은 **s87**, 진단은 **s89**다. P1 SI 운동, P2 물리 birth,
P3 보존 deposit/micro/증발, P4b 국소 고임→head 복귀까지 게임 관찰이 있다.
**s91–s122는 오프라인 수송·실행기 연구이며 아직 CSP에 연결하지 않았다.**
그 이후의 WARP 통과나 명령 수 감소를 현재 게임의 FPS 개선으로 해석하지 않는다.

| 구간 | 확보한 것 | 남은 조건 |
|---|---|---|
| P0/P1 | 날씨·단위 입력, G의 중력 미포함 관찰, 체적/질량/SI 운동, 표시 gain 분리 | 회전 입력·실제 강우 flux/재질/국소 풍속 보정의 불확실성 |
| P2 | DSD/가상 충돌/체적 분배·원장, 실제 표면 면적/법선 birth | 다양한 날씨/차폐/phase와 고속 충돌의 전체 실측 적합도 |
| P3/P4b, s81–s87 | head→trail 체적 차감·deposit, micro/증발/유출, 국소 고임 복귀 | 수송 시간 정확도, 경로 추종·보존 흡수, head/film 운동·광학 통합 |
| s91–s99 | 양수 다중 셀 수송, 시간 부채/거부/재시도, 힘·운동량 원장, 정확도 기준해 | 일반 수렴/압력·접촉선 closure, 실시간에 쓸 저비용 오차 판단 |
| s100–s111 | pass 융합, metric cache, 사용하지 않는 bank 제거, parent/copy ABI | 실제 GPU에서 유리한 선택과 전체 pipeline 비용 |
| s112–s118 | GPU 상주·target 재사용·원자적 게시·용량 제한·비동기 완료/취소/리셋, 진단 분리 | 실시간 입력 queue/backlog, 실제 장치 오류 복구 및 CSP 자원 매핑 |
| s119–s122 | oracle 분리, typed provider, 불변 graph, 구간별 snapshot, shader layout 재사용 | 상수 버퍼 생성/수명 재사용, live adapter 및 게임 채택 검증 |

Smear와 legacy local impact film은 새 기본 물리의 필수 항목에서 제외했다.
core 물·sheet·impact의 표현을 먼저 검증하고 필요할 때 보정 효과를 다시 판단한다.
실제 물리 직경/질량을 표시 gain에 따라 바꾸지 않는 원칙도 유지한다.

## 2. 게임에서 측정한 지표

| 측정 | 결과 | 해석 범위 |
|---|---|---|
| 재설계 전 성능 기준, 낮60% | 79→59 FPS = 12.66→16.95ms, **+4.29ms** | 앱 전체 차이. GPU만의 시간 아님 |
| 재설계 전 성능 기준,100% | 75→45 FPS = 13.33→22.22ms, **+8.89ms** | 같은 baseline에서 incremental ms로 비교해야 함 |
| P1 프리뷰, 정차 | 앱 전93, legacy71, P1 SI76 FPS | 한 장면. 모든 주행/강수 조건의 성능 결론 아님 |
| P2 검증, 정차 | 앱 전91–94, P1만/P1+P2 모두72–73 FPS | 이 조건에서 P2 추가비용을 FPS 정밀도로 구분하지 못함 |
| P3 추가 | P2 66 / P3 65 FPS, 약1FPS 관찰 오차 | 0ms 추가비용 또는 전체 조건 통과를 뜻하지 않음 |
| P3 메모리,3분·토글 | 3분 후 최저62.13MB;5회67.76 /40회64.45MB | 상승 누수 패턴을 입증하지 못함. GC/초기 워밍업 바이어스 존재 |
| P4b OFF/ON, 약40초 | 모두67 FPS;82.52/85.99MB | 순간 차이3.47MB. peak VRAM/누수/장시간 plateau 측정 아님 |

출처: [설계 성능 기준](RAINFX_S73_PHYSICS_WEATHER_REFACTOR_DESIGN.md),
[P1/P2 검토](RAINFX_S78_BIRTH_DISTRIBUTION_AND_BUDGET.md),
[P2 게임 검토](RAINFX_S80_P2_GAME_REVIEW_AND_MERGE.md),
[P3 게임 검토](RAINFX_S82_P3_GAME_REVIEW.md),
[P4b 게임 검토](RAINFX_S87_P4B_GAME_REVIEW.md).

### P4b의 실제 물 원장과 수송 제한

| 지표 | 정차 | 137km/h |
|---|---:|---:|
| film 재고 mm³ | 227.257 | 500.909 |
| 최대 두께 µm | 473.947 | 874.148 |
| 1mm 초과 film 재고 mm³ | 0 | 0 |
| pool→head 복귀 누계 mm³ | 9.385 | 306.870 |
| 보존 residual mm³ | .002228 | .022490 |
| residual/input | 6.99e-7 | 1.72e-6 |
| 제한된 film 질량 비중 | 11.75% | 17.25% |
| 질량 가중 속도 보존율 | 91.84% | 86.28% |
| max Courant | 17.28 | 60.21 |

물 보존과 극단 수주 감소는 관측됐지만, Courant 제한 때문에 국소 수송이 느려지는
문제는 남았다. 이전 P4a 최대 두께13.14/5.24mm, 속도 보존52.08/59.72%와는
누적 시간·공급 이력이 달라서 정밀한 개선율을 계산하지 않는다.
[원본 평가](RAINFX_S87_P4B_GAME_REVIEW.md)와 `s87/game_checks.json` 참조.

## 3. 오프라인에서 생성한 지표

| 분류 | 대표 측정 | 의미와 한계 |
|---|---|---|
| 단위·물리/표시 분리 | 4096×1024 기준6 atlas texels/mm; 실제 이동·면적에는 국소 Jacobian 사용 | 화면 pixel/mm가 아니며 전 위치의 고정 metric도 아님 |
| 보존·힘 적분 | s100 실제 곡면 체적 residual1.835e-7mm³, 운동량1.249e-8mm³·m/s | 특정 fixture의 수치 원장. 물리적 사실성 전체 인증 아님 |
| 시간 정확도 | s99 공통16분할 기준 차이: coarse9.33%,8분할2.69%, embedded1.66%/.718% | 공통 수치해와의 차이. 참값 오차나 일반 수렴 증명 아님 |
| 정확도 비용 | 위 embedded 실행1064/2812 draws | 정확도 reference용이며 실시간 채택 불가 수준의 비용 |
| pass 수 | embedded1회76(s99)→73(s100)→67(s101) | 동일 계산의 구조 개선. target GPU ms/FPS 환산 불가 |
| copy·target | s112 실제160×90: hybrid/full-copy69draws,23/29copies; 풀8,165,424B | default target 합계. imports/staging/buffer/driver 제외 |
| 목표 크기 기호 예산 | 1024×256/4096-head hybrid copy92MiB, 새 target 예약141.89MiB | 실제 전체 workload 실행·peak VRAM 측정값 아님 |
| 장기 소유권 | s115 131call×2; steady target194000B, 마지막32call 신규 target0 | 작은8×32 fixture.131개의 서로 다른 날씨 step 아님 |
| 진단 분리 | s118 lean은 경로당7969개 per-flight staging/map 제거 | 명시적 경계/최종 test readback은 남음 |
| oracle 분리 | s119 이후 backend expected-array0B, 없는 oracle 파일로 실행 통과 | 전체 CPU 메모리0B 또는 완전 무파일 실행을 뜻하지 않음 |
| 입력 대여/반환 | s120 경로당1245/1245, 미반환0 | 입력 snapshot 수명과 실패 정리 검증 |
| graph 재사용 | s121 template 경로당45등록/56바인딩, 최대 resident3 | 정적 재검증/복사를 bind에서 제거. RSS 측정 아님 |
| shader layout, 이번 s122 | 경로당 리플렉션 순회9578→615; 상수 버퍼 생성4714 유지 | CPU 작업 구조 감소. 실제 CPU/GPU 시간은 미측정 |
| GPU 일치·오류 | s122 2104명령/224flight,17candidate 거부+10packing guard, D3D 경고0 | 같은 frozen 후보 반복.224개 독립 날씨 검증이 아님 |

위 항목은 서로 다른 크기와 단계의 결과다. 합산해서 누적 FPS 개선, peak memory 감소,
전체 물리 검증 건수로 제시하지 않는다. s122의 draw/copy 수와 최종 GPU bytes는 s121과 같다.

### 보존하는 측정 계열

- 날씨: raw/liquid intensity, wetness/water, RH/T/p/dew point/공기밀도, 상대풍,
  G/관성, 타입 전환·차폐·입력 유효성.
- 방울: 등가/접촉/표시 직경, 체적·질량, 크기별 고착/이동, birth 분포·도착률,
  충돌·반발·슬롯 용량 손실·병합·유출.
- 수막: µm 높이·coverage·재고, 공급/이동/증발/유출/내부 전환 원장,
  제한 질량·Courant·속도 보존, head/trail 좌표·시간 일치.
- 수치: 양수성, coarse/finer norm, 수량·운동량·impulse residual,
  accepted/refused step, retained time ticks, split/together·XY/YX 차이.
- 실행기: draw/copy/업로드, target·cache byte/entry와 생성/재사용/퇴거,
  pending/flight/epoch/generation, query 완료/실패·취소·게시, provider lease,
  template 등록/바인딩, reflection/packing/buffer, 진단 readback 및 D3D 경고.
- 게임 비용: app on/off frame ms, stage별 CPU/GPU ms, GC 후 최저·peak·추세,
  startup/compile stall, p50/p95/p99,10분 warm run. **뒤의 상세 비용·분위수는 아직
  전체 채택 조건으로 측정·통과된 상태가 아니다.**

`tools/summarize_s122_progress.py`는 기존 s73–s122의 delivery/check report를
해시·필드 이름·원본 경로와 함께 `diagnostics/2026-10-17/s122/measurement_index.json`에
색인한다. 큰 배열·중복 fixture의 실행 수를 새 실험으로 합산하지 않는다.

## 4. 남은 로드맵과 다음 완료 기준

| 순서 | 구현/검토 | 완료를 판단할 증거 |
|---|---|---|
| 이번 s122 | shader별 고정 reflection layout, 구간별 패킹/사전검증 | 기존 GPU 결과 일치, 캐시 수명/용량·오류 거부, 순회 감소 확인 |
| 다음 | 상수 버퍼 packet을 준비·완료까지 보유하고 bounded 재사용 평가 | in-flight overwrite/조기 재사용0, 동일 byte, 생성·상주 예산과 비용 |
| live adapter 준비 | SDK를 확인한 CSP 자원/이벤트 매핑, 날씨·geometry·head 입력, receipt/queue/backlog | frozen file 대신 실제 입력, 거부 중 물·시간 부채 보존, pause/replay/reset 정책 |
| 정확도·비용 채택 판단 | 비싼 triple reference를 대체할 저비용 판정/제한 작업량, depth/drag/contact closure | 고전단·젖음 전선·압축/곡면 공통해 비교, 양수·보존·진행률과 수렴 |
| 통합 물/광학 | head의 wet-path 반응·필요시 paired absorption, 공통 수면 normal/굴절 | 물 복제0, head/trail 시간·폭·경로와 실제 sheet 굴절, 표시 gain 독립 |
| 게임 검증/채택 | 전체 날씨·풍향·차폐·재질·속도·phase,1024/4096slot,60/100% 강수 | 같은 scene incremental ms·stage timing·p95/p99,10분 메모리/시작 지연·복구 |
| 최종 표현·정리 | 승인 크기 분위수·곡선/경계·유리 스택 회귀, UI·단위·레거시 정리 | screen diameter p10/p50/p90와 사용자 시각 검토, Smear 등 보정 필요성 재판단 |

live adapter와 정확도/비용 연구는 모두 채택에 필요하다. 어댑터가 연결된 것만으로
모델의 정확도나 성능을 통과 처리하지 않는다. 헤드/필름 흡수와 추가 분열·곡선 subdivision은
필요성과 비용을 확인한 뒤 도입하며, 완전 CFD/SPH나 모든 쌍 병합은 목표가 아니다.

## 5. 재현 및 상세 문서

- [s122 구현·검증](RAINFX_S122_SHADER_BINDING_LAYOUT.md)
- [원래 설계/채택 gate](RAINFX_S73_PHYSICS_WEATHER_REFACTOR_DESIGN.md)
- [현재 게임 모델의 한계](RAINFX_S87_P4B_GAME_REVIEW.md)
- [정확도 기준해](RAINFX_S99_TEMPORAL_COUPLING.md)
- [전체 이력 로드맵](RAINFX_ROADMAP.md)

```text
docs/tools/check_s122_layout.py
docs/tools/summarize_s122_progress.py
docs/tools/finalize_s122.py
```
