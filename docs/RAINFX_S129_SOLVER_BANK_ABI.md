# RainFX s129 — existing solver bank helpers on actual CSP

Date: 2026-10-17
Status: ACTIVE — actual helper/packet ABI passes; full solver consumers remain open

## 1. 연결 범위

s128의 임의 주소 probe에서 정수 Load가 정상 동작했으므로, 이번에는 기존 solver가
사용하는 **s109 `rvBankLoad`와 s110 `rvBankGridLoad` 원문**을 CSP에 연결한다.
두 함수는 원본 파일과 정규화된 전체 source text가 일치하는지 검사한다.
`rvEndLoad`/`rvMeanLoad` wrapper도 기존 factory가 만드는 문자열과 일치한다.

texture parameter를 함수 인자로 전달하며 `txAdvEnd`와 `txAdvMean`은 같은 parent를
가리킨다. 값 packet은 기존 이름/종류인 `gAdvGrid`(vec2), `gBankEndRow`(number),
`gBankMeanRow`(number)를 그대로 쓴다. grid를 큰 parent 크기로 바꾸지 않는다.
ordinary values 방식이며 typed packet은 s125 bridge가 복사한다.

| 논리 크기 | parent 크기 | End row | Mean row |
|---|---|---:|---:|
|8×4 |8×12 |0 |8 |
|13×7 |13×21 |7 |14 |
|1056×288 |1056×864 |576 |0 |

입력은 float32 RGBA의 full-width contiguous single-mip row band만 받는다.
host validator는 음수/소수/범위 밖 row, 다른 포맷, column/stride view, 잘못된 grid,
누락/추가 descriptor를 거부한다. 기존 managed bridge의 한도에 맞춰 parent/grid를
1..4096으로 제한한다. 이는 offline s109의 더 넓은 한도를 확장 승인하는 것이 아니다.
row origin은 정수 행이면 되며 논리 높이의 배수로 제한하지 않는다.

## 2. 검사하는6개 경로

1. checked helper로 End 읽기.
2. checked helper로 Mean 읽기.
3. probe의 명시적 좌표/mip 검사 뒤 grid helper로 End 읽기.
4. 같은 검사 뒤 grid helper로 Mean 읽기.
5. 원래 wrapper 이름으로 `End + 0.5 × Mean` 조합 읽기.
6. query의 selector에 따라 End/Mean wrapper 선택 읽기.

grid helper는 자체 경계 검사가 없다. 이번 probe에서는 임의 주소를 먼저 검사한
뒤에만 호출한다. **s110의 frozen solver call-site proof를 켜거나 새로 승인하지 않는다.**
알 수 없는 solver 코드의 unchecked neighbour load를 허용하지 않는다.

각 경로의64개 query 중56개는 유효한 corner/내부 좌표이며8개는 X/Y 경계,
음수/양수 mip와 큰 범위 초과다. 인접 bank 값을 읽어서는 안 되는576개 invalid
출력(3개 grid ×6개 reader ×8개 query ×4채널)을 독립 기준값과 대조한다.

control은 parent prefix, query texture, 별도로 생성한 logical End/Mean이다.
logical oracle는 같은 해석식으로 독립 생성한 pattern이며 live physical stock의
복제본이나 source/trail 물량 입력이 아니다. 총7,680개 float를 R32FLOAT로 읽는다.
큰 부호 교대 정수 pattern을 사용하고 정확 일치/float32 ULP를 검사한다.

## 3. 결과

사용자가 one-shot 절차를 실행하고 State: observed를 확인했다. 실제 CSP 로그에서
**7,680개 float를 수집해 모두 독립 기준값과 정확히 일치**함을 확인했다.
3개 grid ×6개 reader 경로의 최대 절대 오차와 float32 ULP 차이는 모두0이다.
parent prefix·query·독립 logical End/Mean control도 전부 일치한다.

잘못된 좌표와 mip의576개 reader 출력은 모두 정확히0이므로, 이 검사에서는 인접
bank 값이 새지 않았다. 함수의 texture 인자, 서로 다른 End/Mean row uniform,
원래 wrapper를 통한 조합·선택 경로가 실제 CSP에서 검증됐다.

33개 draw는 각각1회 accepted됐으며24번째 draw는 시도1회, 나머지는2회였다.
shader 준비 대기가 accepted prefix를 반복하지 않았다. 이 관찰을 일반 GPU 완료
fence나 전체 solver의 물리/성능 검증으로 확대하지 않는다.

로컬 검증은 host descriptor 거부14개, mocked LuaJIT 실행 제어14개, decoder15개,
scratch installer9개가 통과했다. OFF→ON은 shader 준비 대기 중에 수행하며 이미
accepted인 draw를 반복하지 않는다. callback 역순/중복/오류와 제출 불명확 오류도
검사한다.9개 shader 본문은 synthetic PS_IN/선언으로 FXC `/WX /Ges`를 통과했다.
이 로컬 결과는 실제 CSP shader template 실행을 대신하지 않는다.

## 4. 설치·자원·증거

독립 앱 `D:/Games/Assetto Corsa/apps/lua/realvisor_s129_abi`에5개 파일을 설치했다.
기본 OFF·load당 one-shot이며 사용자 실행 후 observed에서 자동 기록한다.
기존 RealVisor 앱이나 app enable 설정은 수정하지 않는다.

main graph30개 RGBA32FLOAT canvas, R32FLOAT atlas3개, accepted draw33개,
readback3개다. 명목 텍셀 payload는 **24,392,304 bytes (23.26MiB)**이며 실제 GPU
할당량/peak memory나 반복 solver의 성능 수치는 아니다. 시간/FPS는 측정하지 않았다.
준비 대기는 draw당256회로 제한하며, 제출된 GPU canvas를 시간 추정으로 retire하지
않는다. strict completion은 false다.

`docs/diagnostics/2026-10-17/s129/`에 source baseline,9개 compiled body,
`abi_checks.json`, `parser_fixtures.json`, `installer_checks.json`, frozen 실행 package와
최초 설치 report/영수증을 둔다. `actual_probe_lines.txt`와 `actual_observation.json`에
실제 tagged 원문과 판독 결과를 보존하고 byte 범위·prefix hash·설치 파일 hash를
대조했다. `observation_update/`에는 대기 상태의 delivery와 수정 전 문서를 보존했다.
이전 단계의 증거를 다시 쓰지 않는다.

builder는 s128의 bounded one-shot 실행 shell을 보존해서 새 파일로 생성한다.
기존 s128 파일은 수정하지 않는다. 모든 새 shader/recipe는 s129에 별도로 정의한다.
사용 API는 s127/s128에서 확인한 API와 같으며 설치 SDK hash를 다시 확인한다.

## 5. 남은 작업

이번 연결은 **helper/texture 인자/packet ABI** 검증이다. 전체 axis map·loss·gather
consumer의 source와 값 packet, live head/film stock 소유권은 아직 연결하지 않았다.
다음은 기존 shader consumer를 실제 CSP의 dependency graph에 넣고 별도 logical
texture 경로와 비교하는 작업이다. 그 뒤 live 입력 queue, 공통 광학, 물리 정확도와
목표 GPU/CPU 비용 검증이 남는다.

생산 게임 물리는 s87, 진단은 s89 상태다. 기존 runtime53개, root INI3개와 s91–s128
소스362개를 보존한다. commit/push는 하지 않는다.

재현 도구:

```text
docs/tools/build_s129_probe.py
docs/tools/check_s129_abi.py
docs/tools/check_s129_install.py
docs/tools/install_s129_probe.ps1
docs/tools/collect_s129_observation.py
docs/tools/finalize_s129.py
```
