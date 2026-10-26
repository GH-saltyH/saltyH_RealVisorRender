# RainFX s128 — actual CSP integer addresses and parent-bank reads

Date: 2026-10-17
Status: ACTIVE — all specified actual reader cases pass; transport integration remains open

## 1. 목적과 실제 결과

s127에서는 특정8×4 역방향 정수 `Load` 수식이 실패하고 `SampleLevel` 분기가
일치했다. 이것을 모든 정수 Load의 문제라고 일반화하거나, 물리 계산 전체를
선형 sampling으로 교체하지 않았다. s128은 별도의 주소 texture에서 좌표를 읽고
parent의 row bank를 찾아가는 경로를 실제 CSP에서 검증한다.

사용자가 **RealVisor s128 bank reader probe**에서 Enable → Run bank reader probe once를
실행했다. 실제 preview649/4184 로그의6,912개 float를 수집했으며, 아래18개 조합의
reader 출력4,608개 값이 모두 독립 정수 기준값과 **정확히 일치**한다.
최대 절대 오차와 float32 ULP 차이는 모두0이다.

| 논리 크기 | bank 수 | parent 크기 | query/bank-reader | 6개 reader 결과 |
|---|---:|---|---|---|
|8×4 |1 |8×4 |64개 중57 valid,7 invalid |전부 정확 일치 |
|13×7 |3 |13×21 |동일 |전부 정확 일치 |
|1056×288 |3 |1056×864 |동일 |전부 정확 일치 |

6개 방식은 signed inline, signed vector, unsigned vector, float-floor 정수화,
signed vector를 받는 helper의 Load, texel 중심 `SampleLevel`이다.
invalid query는 음수/상한 X·Y, 음수/상한 bank, 잘못된 mip이며 **bank offset 계산 전에**
차단한다. 모든18개 조합에서 invalid7개×4채널, 총504개 값이 정확히0이다.
이는 인접 bank 값이 논리 경계 밖으로 새지 않는지 확인하는 검사다.

parent prefix, 주소 texture, 독립 생성한 logical oracle의 control도 전부 일치한다.
accepted draw는34개 모두1회다. 시도는17번째 draw만1회, 나머지는2회이며,
shader 준비 대기로 인해 이미 accepted인 draw를 재실행하지 않았다.

**해석:** 이번 경로에서 정수 Load는 정상 동작한다. s127의 실패 원인을 해결했다고
단정할 수는 없다. 두 실험은 좌표 입력·shader·의존 graph가 다르다. 또한64개 query는
전 픽셀 전수 검사나 임의의 크기에 대한 증명이 아니다.

## 2. 이웃 값 혼합을 드러내는 패턴

seed는 픽셀마다 부호가 바뀌는 약±1,048,576, X마다 부호가 바뀌는 약±4,194,304,
좌표 및 parent 선형 index를 네 채널에 넣는다. 모든 seed 값은 float32로 정확히
표현되는 정수다. bank마다 다른 Y/index를 가지므로 이웃 bank나 좌표를 읽으면
기준값과 구분된다. 큰 값에 비례하는 상대 허용 오차를 사용하지 않는다.

주소 texture에는 corner, 비정방형 내부 좌표, bank 전환, invalid7개가 포함된다.
유효한 논리 좌표를 역방향으로 변환한 뒤 row offset을 더한다. 별도 logical texture는
같은 물리 bank 좌표의 해석식을 **독립 생성**하며, 실제 stock의 복제본은 아니다.
현재 logical oracle와 중심 sampling에서도 이 query들에 대한 혼합 오차는0이다.

첫 판독의 small parent-prefix 기준식에는 범위를 벗어난 마지막32픽셀에도 seed를
계산하는 오류가 있었다. 실제 GPU 값은0이므로 기준식을 수정하고 같은 원시 로그를
다시 판독했다. 실행 Lua/HLSL·설치 파일은 변경하지 않았다. 잘못된 첫 판독도
`initial_decoder_output.json`에 보존했다. **논리 bank guard 검사는 이 직접적인
parent 범위 밖 Load 동작에 의존하지 않는다.**

## 3. 실행·자원·실패 처리

- 설치 경로: `D:/Games/Assetto Corsa/apps/lua/realvisor_s128_reader`의4개 파일.
- 기본 OFF, load당 one-shot, shader 준비 대기는 draw당 최대256번.
- main graph31개 RGBA32FLOAT canvas와 R32FLOAT atlas3개; accepted draw34개,
  readback3개. 최대 texture binding은 atlas의11개다.
- 명목 텍셀 payload **29,255,200 bytes (27.90MiB)**. 실제 driver 할당량·peak memory나
  GPU/CPU 시간·FPS는 측정하지 않았다. 이것은 반복 실행하는 solver의 비용 수치가 아니다.
- callback 순서 역전·중복·오류에서 CPU readback은 dispose하며, 제출된 GPU canvas는
  임의의 프레임 지연을 완료 fence로 간주해 dispose/reuse하지 않는다.
- 물리 큐의 strict completion capability는 계속 false다. observed는 이 패턴의
  readback을 얻었다는 뜻이며 일반적인 GPU retirement 증거가 아니다.

실제 설치 전 scratch installer9개, mocked LuaJIT 실행 제어14개, decoder15개를
검사했다.9개 shader 본문은 synthetic PS_IN/선언으로 FXC `/WX /Ges`를 통과했다.
별도로 실제 게임에서 전체 graph를 실행한 결과를 보존한다. mock 성공이나 synthetic
컴파일을 실제 CSP 결과로 대체하지 않는다.

기존 s127에서 감사한23개 SDK block을 포함하는 설치 SDK 전체 hash가 그대로다.
이번 probe는 그때 사용한 canvas·ordinary values·readback API만 사용한다.

## 4. 재현 자료와 보존

`docs/diagnostics/2026-10-17/s128/`:

- `actual_probe_lines.txt`, `actual_observation.json`: tagged 실제 로그와 재판독 결과.
- `log_start.json`: 시작 byte offset, prefix hash, file identity, UTC 시각.
- `installation/reader_checks.json`, `installation/install_receipt.json`: 최초 설치에
  실제 사용한 report와 영수증. decoder 수정 후 report와 혼동하지 않는다.
- `package/realvisor_s128_reader/`: 실제 실행 파일과 byte hash가 같은4개 파일.
- `reader_checks.json`, `parser_fixtures.json`, `installer_checks.json`: 로컬 검사.
- `delivery.json`, `source.diff`: 최종 보존·결과 감사.

collector는 같은 로그 prefix 뒤의 값만 취한다. 게임 재시작으로 로그가 교체되면
marker 이후의 CSP session header가 있어야 새 파일을 인정한다. 가장 최근 dump가
불완전하면 과거의 성공 dump로 되돌아가지 않는다.

기존 runtime53개, root INI3개, s91–s127 소스352개와 기존 stage 결과·asset을 보존한다.
게임의 RainFX 물리/광학 본체는 s87, 진단은 s89 상태다. commit/push는 하지 않았다.

## 5. 다음 구현

정수 reader를 배제할 근거는 없다. 다음에는 **기존 s109/s110 bank ABI의 실제 shader
함수와 실제 값 packet**을 이번에 관찰한 경로에 연결한다. texture parameter를 받는
generic helper, 동적 baseRow/gAdvGrid 및 기존 solver pass의 연결은 별도 검증 대상이다.
검증된 조합에서 signed vector/정수 Load를 우선 후보로 유지하며, 선형 sampler로
물리 stock 전체를 대체하지 않는다.

이후 live source/stock의 공간 소유권, 입력 queue, 공통 head/film 광학 및 실제
GPU/CPU 비용 검증이 남는다. 이번 결과는 그 통합이나 일반 완료 fence를 승인하지 않는다.
