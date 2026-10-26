# RainFX s127 — actual CSP observation and reverse-read isolation

Date: 2026-10-17
Status: ACTIVE — actual preview649 observations captured; diagnostic sampling branch passes; full transport not integrated

## 1. 실행 환경과 범위

사용자가 시작한 **30초 정지 후4랩 주행 리플레이**를 유지한 상태에서 독립 앱을 실행했다.
기존 RainFX 물리·광학·설정을 변경하지 않았다. 게임 본체 물리는 s87, 진단은 s89 상태다.

실제 CSP 로그 첫 줄과 dwrite.dll version은 **0.3.0-preview649/4184**다.
기준 SDK는 preview634였으므로 설치된 preview649 app SDK를 다시 감사했다.
사용한23개 함수·constructor·enum 문서 block이 전부 일치한다. 선언 수는2092개다.
검사한 공개 SDK에는 일반 native buffer/fence API가 여전히 선언돼 있지 않다.

Computer-use 스킬로 리플레이 창을 확인했으나 자동 클릭과 게임 커서의 위치가 어긋나
실행 버튼 조작을 확실히 검증할 수 없었다. 이후 버튼은 사용자가 직접 눌렀다.
로그 수집·범위 검사·수치 대조는 로컬 도구로 수행했다. 다른 앱에는 입력하지 않았다.

작업공간 밖 쓰기 승인을 받아 다음 **독립 앱 폴더만** 설치했다.

- `D:/Games/Assetto Corsa/apps/lua/realvisor_s126_probe`:4개 파일.
- `D:/Games/Assetto Corsa/apps/lua/realvisor_s127_trace`:5개 파일.

두 앱은 기본 OFF·load당 one-shot이다. installer는 RealVisor 본체/앱 설정을 수정하거나
앱을 자동 enable하지 않는다. 이후 사용자가 probe를 enable하고 실행했다.
GPU 작업 제출 후에는 완료 fence를 추정해 canvas를 dispose/reuse하지 않는다.

## 2. 첫 실제 s126 결과 — 실패를 보존

UI와 독립 로그 분석 모두 `observed_mismatch / unmatched`였다.
128개 출력은 모든 픽셀에서 **`(0,0,0,-2)`**, 기대값 대비 최대 절대 오차는 **43.125**다.
`-2` 상수는 도달했지만 앞 texture 입력이0처럼 보이는 형태다.
이 결과만으로 source 생성·binding·좌표·readback 중 하나를 원인으로 확정하지 않았다.

실제 기록은 `s126_actual_observation.json`, `s126_probe_lines.txt`에 보존했다.
기존 s126 소스·패키지·보고서를 고쳐 통과한 결과처럼 만들지 않았다.

## 3. s127 trace v1 — 입력 이름 가설 배제

seed/copy/original/texture 이름 변경/control의5개 구역을 한 R32FLOAT atlas로 읽었다.
640개 값, accepted draw5개가 각각1회, pass별 시도는2회였다.

| 구역 | 기대값과 최대 절대 오차 | 관찰 |
|---|---:|---|
| seed |0 |scalar·bool·vec2/3/4·row matrix의 비대칭 패턴 일치 |
| copy |0 |정방향 `Load` whole-copy 일치 |
| original transform |43.125 |`(0,0,0,-2)` |
| texture 이름 변경 transform |43.125 |동일 실패; 이름만의 문제라는 가설은 지지되지 않음 |
| 직접 출력 control |0 |R32FLOAT signed/1 초과 값·픽셀 순서 일치 |

원본 trace와 **실제로 실행한5개 파일·설치 영수증·검사 report**를 `trace_v1/`에 복사했다.
이후 변경한 probe의 결과를 v1 소스에 소급 연결하지 않는다.

## 4. s127 trace v2 — 확인된 실패 구간과 대응

uniform 이름, sampling 방식, 실제 UV를 추가해1,024개 값을 한 번에 읽었다.
accepted draw8개가 각각1회이고, 모든 pass는 시도2회였다.

| stage | 기능 | 최대 절대 오차 | 결과 |
|---:|---|---:|---|
|0 |seed |0 |일치 |
|1 |정방향 whole-copy `Load` |0 |일치 |
|2 |원래 반전 `Load` |43.125 |불일치 |
|3 |texture 이름 변경 후 반전 `Load` |43.125 |불일치 |
|4 |uniform도 `gProbeOffset`으로 변경한 반전 `Load` |43.125 |불일치 |
|5 |같은 source를 `SampleLevel(samLinearClamp,1-pin.Tex,0)`로 읽음 |**0** |**128개 값 일치** |
|6 |`q=floor(pin.Tex*(8,4))`와 실제 UV 직접 출력 |0 |예상 좌표·픽셀 중심과 일치 |
|7 |직접 출력 control |0 |일치 |

control은1…32, -1, 분수 좌표를 포함한다. seed의50대 양수와 sampling 결과의 음수도
정확히 읽혔다. 이번 측정에서는 R32FLOAT readback이0…1로 clamp되지 않았다.
일반 `floatValue` 문구의0…1 설명을 모든 format 값에 대한 clamp로 적용할 수 없다.

**확인한 결론:** 이 CSP 세션의 해당 shader에서
`Load(int3(7-q.x,3-q.y,0))`로 반전 읽기한 경로는0 입력을 재현하고,
같은 source·정상 UV에서 반전 `SampleLevel` 경로는 전체 기대값과 일치한다.
texture/uniform 이름 변경으로 해결되지 않았고, 전체 `Load`가 고장 난 것도 아니다.
정방향 copy와 atlas의 `Load`는 실제 통과했다.

CSP의 비공개 template/compiled code 내부에서 왜 이 수식이0을 읽는지는 아직
확정하지 않았다. compiler·binding 내부 버그를 특정한 것으로 기술하지 않는다.

실제로 실행한 v2 소스와1,024개 값은 `trace_v2/`에 동결했다.
후속 검사기 수정과 별개로 당시 source report/설치 hash를 다시 확인할 수 있다.

## 5. 확인한 분기를 코드에 반영

`docs/tools/s127_verified_recipe.lua`는 실제 통과한 stage5의 shader/cacheKey/texture/value
schema를 그대로 선택해 **3-pass 진단 recipe 후보**를 만든다. seed → copy → sampled
transform이다. target 번호만3으로 바꾸고 세 번째 입력은 `gProbeOffset=-2`로 유지한다.
모의 bridge의 pending/resume와128개 값도 다시 대조했다.

**적용 한계:** 실제 게임에서 통과한 것은 v2 graph 안의 이 분기다. 추출한3-pass recipe
전체를 별도 앱으로 다시 실행한 것은 아니다. 후보 scope에 이를 명시했다.
테스트된8×4 픽셀 중심에서는 결과가 정확하지만, 임의 해상도·비정방형 parent bank·
경계·비2의 거듭제곱 크기에서 linear sampling이 항상 point `Load`와 같은 것은 검증하지
않았다. 수송의 보존량·history용 일반 reader를 이 코드로 일괄 교체하지 않는다.

sampling branch는 lookup1개인 진단 대안이지만, 실제 CPU/GPU ms나 FPS 비용 비교는 없다.
새 physics transport와 queue에는 연결하지 않았다. **GPU completion/retirement gate는
계속 false**다. readback callback을 일반 fence로 승격하지 않는다.

## 6. 설치·수집·검증 도구

### 설치

`install_s127_probe.ps1`는 기본 plan이다. `-Install` 때만 지정 독립 폴더에 쓴다.
모든 source hash를 검사하고 link/reparse·다른 파일·수정된 target을 거부한다.
동일 파일은 다시 쓰지 않는다. `-Trace -UpdateOwned`는 직전 설치 영수증과 현재 hash가
일치하는 자체 파일만 백업 후 갱신한다. v1→v2에서는2개 파일만 갱신했다.
사용자 편집이 끼면 갱신을 거부한다.14개 임시 게임 폴더 검사가 통과했다.

### 관찰 수집

`s127_probe_observation.py`는 실행 전 기록한 로그 byte offset/prefix hash/file identity
뒤의 probe 메시지만 저장한다. 원본 CSP 로그 전체를 프로젝트에 복사하지 않는다.
이전 로그·회전·잘린 dump·중복 channel·NaN·infinite·잘못된 count를 거부한다.
초기128개와 trace640/1024개를 독립 계산으로 대조한다.
31개 합성 parser 입력,4개 로그 경계 검사가 통과했다.

### 수치/본문 검사

`check_s127_trace.py`:11개 모의 control,5개 synthetic HLSL 본문 compile 통과.
실제 CSP template를 재현한 FXC 검사라고 주장하지 않는다. 실제 실행 증거는 별도의
fresh 로그와 설치된 파일 hash다. 일반 전체 수송/GPU 비용 검증과 구분한다.

baseline479개 중53개 runtime Lua/HLSL,3개 INI,이전 s91–s126 파일340개와 asset hash,
Git HEAD를 보존한다. 기존 파일 변경은 index/roadmap뿐이다. Git commit/push는 하지 않았다.

## 7. 다음 단계

1. 이번에 통과한 좁은 reader 계약을 유지한 채 임의 integer address/parent-bank reader의
   CSP 호환성을 실제로 검증한다. 현재 실패를 전체 solver로 확산하지 않는다.
2. managed resource 수명·live source/geometry/pose 소유권과 bounded queue 정책을
   연결한다. 순서 데이터 관찰과 strict physical completion을 별도 계약으로 유지한다.
3. 저비용 수송 정확도·물리 closure·head/film 공통 광학·60/100% 목표 CPU/GPU ms·
   장시간 memory/device recovery 검증은 계속 남아 있다.

## 8. 재현

```text
docs/tools/check_s127_install.py
docs/tools/check_s127_observation.py
docs/tools/check_s127_trace.py
docs/tools/audit_s127_runtime_sdk.py
docs/tools/s127_probe_observation.py --capture --trace
docs/tools/finalize_s127.py
```

`--capture`는 표시한 실제 실행 이후 fresh log marker와 설치 영수증을 사용한다.
이미 동결한 관찰을 재현하려면 finalizer로 저장된 로그/값을 검사한다.
새 marker 없이 과거 dump를 새 실행으로 취급하지 않는다.

증거·버전별 실제 패키지·백업·영수증·source diff:
`docs/diagnostics/2026-10-17/s127/`.
