# s230 — CPU 분할 계측 재개와 다음 개발 우선순위

2026-10-22. s229 게임 채택 기준 v1 적용. 독립 native 진단이며 게임 물리는 s87이다.

## 1. 결과와 판단

event/sleep 각각 계측 OFF·ON 한 번, 총4개의 사전 지정된 일반 실행이 모두 통과했다.
실제 물 상태·최종 bank·stock·시간 부채·소유권·메모리 상한 계약을 유지했으며,
이번에는 진단 원장도 모두 비트 일치했다. 허용 오차 경고는0개다.

별도 retained metric 손상 실험은 엄격히 거부됐다. 이전7개 게시 구간과 수락 시간
부채를 보존하고 실패 구간을 게시하지 않았다. 따라서 작은 중간 원장 차이를
허용하는 새 비교가 실제 retained 캐시 변조를 허용하지 않는 것을 확인했다.

**CPU 병목을 분류하는 계측 경로는 통과했다. 성능 최적화·게임 채택 통과는 아니다.**
각 조건1표본이므로 평균/분위수·통계적 속도 향상이나 event 기본 채택을 판정하지 않는다.
동일 결과가 더 나올 때까지 반복하는 실험은 하지 않았다. s223/s208의 원인은 미확정이다.

## 2. 호출 스레드의 비용이 큰 구간

표는 계측 ON 구간의 **호출 스레드 cycle 비중**이다. 자식 scope를 제외한 self 값이며
중첩된 카테고리를 합산해 중복 계상하지 않는다. 전체 프로세스/worker CPU 비중이나
GPU 시간·게임 프레임 ms가 아니며, cycles를 초로 환산하지 않았다.

| 카테고리 | event | sleep | 이번 fixture의 의미 |
|---|---:|---:|---|
| validation | 23.35% | 23.34% | 캐시 완료/stock/retained witness 등의 선택된 검증 self 작업 |
| readback_cpu | 23.34% | 23.16% | Map·읽기 결과 할당/복사/변환·Unmap 등 |
| diagnostic_output | 23.13% | 21.19% | inventory·cache/proof 기록 등 선택된 진단 출력 |
| metadata_preparation | 11.18% | 10.41% | context/index/예약·cache 준비의 self 작업 |
| resource_api | 6.38% | 6.86% | 계측한 D3D 자원 API와 소유 texture 해제 |
| submission_wrappers | 4.98% | 5.33% | 원래 명령 제출 wrapper |
| dispatch_preparation | 2.77% | 2.68% | draw/state/상수 준비 등 self 작업 |
| completion_wait | 0.59% | 1.31% | 대기에서 실제 소비한 호출 스레드 cycles |
| timestamp_resolution | 0.54% | 0.83% | 기존 observer timestamp resolve |
| 미분류 호출 스레드 | 3.73% | 4.89% | scope 외부 작업·계측/회계 overhead 등 |

검증+readback+진단 출력의 합은 약**67.7–69.8%**다. 이들은 상호 중복되지 않는
선택된 self 범주이지만 전부 제거할 수 있는 코드라는 의미는 아니다. 특히 validation
에는 게시 안전에 필요한 검사가 섞여 있다. 이 결과로 게임의 물리 셰이더가67.7%만큼
빨라질 수 있다고 주장하지 않는다.

선택한 범주의 coverage는 약95.1–96.3%다. s222의 미분류 호출 스레드92–94%에서
주요 비용을 구체적으로 분류하는 데 성공했다. 계측 ON 구간당13,711개 scope,
27,422회 scope cycle read를 사용했다. 계측은 무료가 아니며 범주 비중에도 영향을
줄 수 있다. 계측 OFF에서의 순수 범주 비중을 정확히 복원한 것으로 해석하지 않는다.

### 대기 시간과 CPU 사용을 구분

| 실행 | Physical window wall(s) | 호출 스레드 CPU(s) | 프로세스 CPU(s) |
|---|---:|---:|---:|
| event_plain | 1.0436 | 0.5000 | 0.5313 |
| event_meter | 1.1151 | 0.5625 | 0.5781 |
| sleep_meter | 4.1623 | 0.4844 | 0.5313 |
| sleep_plain | 4.1444 | 0.5938 | 0.5938 |

sleep_meter의 대기 self wall은 약3.5441초, event_meter는 약0.5132초다. 반면 호출
스레드 cycle 비중은 작다. 이는 wall stall과 CPU 소모를 서로 바꾸어 설명하면 안
된다는 근거다. 조건당1표본·native 진단 부하이며 warm-up/시스템 잡음과 계측 영향이
섞이므로 차이를 계측의 순수 overhead나 CSP FPS 개선으로 판정하지 않는다.

## 3. 소스·정확성·안전 검사

- 수정된 s223 후보의9개 source/header를 가져와 진단 식별자만230으로 바꿨다.
  역변환 결과가 부모 source와 동일한지 검사했다. 숫자 forcing ID는 바꾸지 않았다.
  그래프·입력·스케줄·물리 CSO·계산식·완료 predicate·GPU 명령 수는 유지한다.
- 기존 CPU-only 중첩/재진입/예외 unwind controls는 sampler가 이름 외에는 동일하므로
  SHA로 확인해 재사용했다. 새 실행 건수나 새 성능 표본으로 세지 않는다.
- 엄격 prefix 검사에서 `run.audit.bin`의 **단 하나의 전체 hash 동등 조건**만 별도
  의미 비교로 옮겼다. 다른 상태/stock/hash/trace/시간/lease/cap 검사는 그대로 실행한다.
  파일을 덮어쓰거나 hash를 정규화하여 동등한 것처럼 만들지 않는다.
- 별도 archive 검사는 모든 이미지·형상·비트를 비교한다. 사전에 선언한 stepLedger의
  impulse/wall xyz만 s229 예산을 적용한다. 다른 자원·체적·NaN/Inf·큰 오차는 거부한다.
- 새 비교기로 원래 s223 저장 실패를 진단 경고1개로 분류했고, 잘못된 자원·작은 체적
  변화·NaN·큰 원장 변화의4개 negative control은 거부했다. 과거 strict 실패는 유지한다.
- 이번4개 실행은 archive까지 완전 비트 일치했으며 새로운 경고를 사용하지 않았다.
- 기존9 published /12 accepted, queue[9,10,11],246 completion events,2260 draws 및
  scoped default peak66,582,496 bytes under66,584,576이 유지됐다. 이는 총 VRAM이 아니다.

일반 실행4개와 뒤의 손상 대조1개는 순서대로 실행했다. native 실패 재시도나 새 GPU
draw/query/copy는 추가하지 않았다. 엄격 `/W4 /WX /O2 /fp:strict` 빌드5개도 통과했다.

## 4. 선택한 다음 작업

**검증 실행기의 기록·readback 비용을 물리 모델 자체의 비용으로 오인해 최적화하지 않는다.**
실제 CSP 프리뷰에 필요한 안전 검사와 깊은 진단 작업을 구분하는 것이 다음 우선순위다.

| 프리뷰에 필요한 처리 | 개발 진단으로 분리할 처리 |
|---|---|
| context/세대/형상/유효성, 제한된 수치 상태, 물/시간 원장, 완료·lease·게시 계약 | 큰 원본 텍스처의 반복 CPU readback, 전체 비트 archive, inventory/proof 대량 직렬화 |
| 잘못된 캐시 후보 거부와 검증된 이전 캐시/fallback 유지 | 매 단계 같은 큰 데이터에 대한 독립 CPU 재계산·기준해 비교 |
| 유한한 작업량과 시간 부채, replay/pause/reset 처리 | 상세 로그·cycle scope·모든 GPU timestamp의 상시 활성화 |

이를 곧바로 모든 validation OFF로 구현하지 않는다. s208처럼 실패값의 크기가 없는
캐시 경로와 실제 CSP GPU 완료/자원 수명은 여전히 안전 계약이다. GPU에 남길 작은
상태/원장, CPU로 돌아올 최소 상태, 완료까지 보유할 입력을 명시한 실행 경계를 먼저
구현하고, 검증 환경과 실제 프리뷰가 같은 물리 입력/모델을 사용하도록 한다.

metadata11%·resource API7%의 미세 개선보다 이 경계를 먼저 정리한다. native의 상수
버퍼·파일 기반 snapshot 구현이 CSP 구현의 실제 병목인지도 아직 확인되지 않았다.
전체 native 부하를 제거한 가상의 FPS 수치나 목표 달성률은 계산하지 않는다.

다음 실제 비용 판단은 CSP 프리뷰의 같은 장면 frame ms와 화면 결과로 수행한다.
기존 s87 경로는 유지하고 새 모델은 검증 가능한 default-OFF 경로로 준비한다.
이번에는 사용자 게임 실행·설정 변경을 요청하지 않는다.

## 5. 증거

`docs/diagnostics/2026-10-22/s230/`: scope_review/build/policy/receipt와4개 일반 실행,
retained metric fault, saved-only audit를 보존한다. `check_s230_partition.py`는 전체
계약/의미 비교·CPU 회계·손상 거부·부모 SHA/mtime 보존을 다시 확인한다.
보고된 결과는 원시 counter에서 계산되며 과거 s223 결과를 수정하지 않는다.

이번 단계는 **계측 경로 통과**다. 아직 새 최적화 성능 통과, event 전면 채택,
장기 안정성, 물리/광학 통합 또는 실제 CSP 연결 완료가 아니다. 게임 파일·설정·
주 앱 코드는 바꾸지 않았으며 commit/push도 하지 않았다.
