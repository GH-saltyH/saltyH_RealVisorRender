# RainFX s126 — standalone managed canvas observation probe

Date: 2026-10-17
Status: ACTIVE — default-off standalone app packaged; actual CSP run pending

## 1. 이번 구현과 게임 상태

s125 다음 단계인 작은 CSP probe를 별도 앱으로 구현·패키징했다.
기존 RealVisor가 이 모듈을 load하지 않으며 설치도 하지 않았다.
현재 게임 물리는 **s87**, 진단은 **s89**다. 사용자 설정·재질·KN5·runtime은 보존했다.

소스: `docs/probes/s126/`. 실행 패키지:
`docs/diagnostics/2026-10-17/s126/realvisor_s126_probe.zip`.
ZIP 내부는 `realvisor_s126_probe/` 아래 manifest, 같은 이름의 entry Lua,
`s126_probe.lua`, 보존한 s125 bridge 복사본의 **4개 파일**이다.
기존 앱을 덮어쓰거나 자동 설치하는 script는 포함하지 않는다.

앱을 로드해도 **Enable은 OFF, 할당0**으로 시작한다. UI의 Enable을 켠 뒤
Run one-shot probe를 눌러야 render.onSceneReady callback에서 동작한다.
OFF 전환은 새 제출을 멈추지만 이미 요청한 readback callback의 데이터 정리는 계속한다.
앱 load당1회만 허용한다. 반복 ON/OFF·Run으로 canvas를 계속 만들지 않는다.

## 2. 무엇을 관찰하는가

### 3개 주 pass

1. **Seed:**8×4 RGBA32F에 비대칭 row matrix와 scalar/boolean/vec2/vec3/vec4를 넣는다.
   `mul(matrix,vector)`와 `mul(vector,matrix)`, 직접 matrix 성분 접근을 함께 사용한다.
   true/false 두 boolean과 false texture placeholder를 같은 고정 schema에 둔다.
2. **Copy:**s125의 같은 크기 whole-canvas `Load` shader를 사용한다.
3. **Transform:**앞 pass의 반대편 X/Y 좌표를 읽고 채널을 섞어 결과를 만든다.
   공간 방향·이전 결과를 읽었는지·matrix 방향을 구분하기 위한 패턴이다.

중간 shader가 pending이면 해당 pass부터 재개한다. 앞서 accepted된 pass는 반복하지 않는다.
한 pass당 최대256회 draw 시도로 제한하고, 초과하면 fault 상태로 보유한다.
시도 횟수는 완료 fence나 실제 compiler 실패 판단에 쓰지 않는다.

이 probe만 **실험 가정**으로 bridge의 logicalOrdered를 true로 둔다. 실제 의존 canvas
출력이 그 가정에 맞는지 조사하기 위한 opt-in이다. physicalCompletion은 false이고,
생산용 queue 또는 기존 앱에 이 능력을 전달하지 않는다.

### 문서에 맞춘 float readback

preview634 SDK의 `ExtraCanvasData:color()`는 **RGBA8888**용,
`floatValue()`는 **R32FLOAT**용으로 문서화돼 있다. RGBA32F를 color로 읽거나
첫 채널만 읽어 matrix 검사에 통과했다고 판단하지 않는다.

따라서 주 결과에서 채널별 R32FLOAT canvas4개로 추출하는 **추가4 draw**를 사용한다.
전체7 draw가 accepted된 뒤 각 R32 canvas에 `accessData`를 한 번씩 요청한다.
callback에서8×4 전체 값과 size·finite 여부를 검사한 뒤 CPU 데이터는 dispose한다.
오류·데이터 없음·잘못된 size·NaN·중복/늦은 callback도 별도로 다룬다.

패턴에는 음수와1보다 큰 값이 있다. `floatValue` 문서의 설명에는 동시에0..1이라는
문구도 있으므로, 실제 signed/범위 보존을 **검사 대상**으로 남긴다. clamping이 있다면
정상 결과로 처리하지 않는다. 실제 readback 오류나 값 범위 문제는 GPU 물리 실패와
구분해 조사해야 한다.

### 결과 해석

독립 계산으로 만든128개 값과 비교한다. 허용 오차는 성분별
`1e-4 + 1e-6 × abs(expected)`다. 다음 후보별 max absolute error를 기록한다.

| classification | 의미 |
|---|---|
| normal | 정의한 수학적 matrix/공간 방향 패턴과 일치 |
| matrix_transposed | matrix transpose 후보와 일치 |
| flip_x / flip_y / flip_xy | 출력 좌표 방향 후보와 일치 |
| matrix_transposed_flip_y | matrix transpose와 Y 반전 후보와 일치 |
| unmatched | 위 후보로 설명되지 않는 값; stale copy/clamp/채널 오류 등 조사 필요 |

`observed_match`는 이 고정 graph의 데이터 관찰이다. 일반적인 모든 CSP shader의
배치·다른 render callback·실제 물리 graph·다중 frame lifetime까지 통과한 의미가 아니다.
Log probe report는 채널별 row-major8×4 값을 로그에 남긴다. 추가 진단 dump는 버튼으로만
실행하고 매 frame 로그를 출력하지 않는다.

## 3. 자원 수명과 비용 한계

- GPU canvas는3개 RGBA32F +4개 R32FLOAT로 고정된다.
  계산상 texel payload는 **2,048byte**다. 실제 driver/RT/SRV/할당 정렬·shader overhead는
  이 수치에 포함되지 않는다. 게임 메모리 실측값이 아니다.
- 정상실행은 accepted draw7회·readback 요청4회다. shader pending에는 추가 시도가 있다.
  GPU/CPU ms나 FPS 이득을 측정하지 않았다.
- 할당 도중 실패하면 아직 draw가 없으므로 이미 생성한 canvas를 정리한다.
- 일부 제출 이후에는 cancel/오류/timeout/readback 완료를 이유로 GPU canvas를 dispose
  또는 재사용하지 않는다. probe instance가 소유한 채 앱 수명이 끝날 때까지 유지한다.
  실제 CSP app teardown/device reset 동작은 아직 검사하지 않았다.
- CPU readback 데이터는 사용 직후 정리한다. callback 결과가 필요 이상으로 누적되지
  않도록 채널4개·각32개 값만 저장한다.

**readback 데이터가 도착했다는 것은 일반적인 GPU retirement fence가 아니다.**
이 probe에는 뒤늦게 읽는 외부 renderer가 없지만, 실제 physics/scene consumer의 마지막
사용까지 끝났다고 확대할 수 없다. s124 queue의 strict gate와 s125 기본 adapter 능력은
변경하지 않는다. 일부 CSP shader 예외는 Lua pcall로 복구되지 않을 수도 있다.

## 4. 로컬 검증 결과

| 검증 | 결과 |
|---|---|
| 실제 LuaJIT / 모의 CSP 시나리오 | **27개 /658동작** |
| 독립 reference |Fraction 기반128개 값 ×6개 방향 후보 |
| 의도한 불일치 검출 |stale copy, 채널 교환,0..1 clamp 모두 unmatched |
| control/readback |pending prefix, OFF 중단·재개, 즉시/지연/역순/중복/늦은 callback |
| 오류 |누락·error·size·NaN·요청 throw·CPU dispose error, draw throw/nil, 할당 실패 |
| attempt budget |7번 pass가256회 pending 후 fault, accepted prefix 유지 |
| entry 기본 OFF |callback 등록1회, canvas 할당0 |
| synthetic HLSL compile |**4개 본문, FXC ps_5_0 /WX /Ges, 경고0** |
| SDK 대조 |**23개** 함수·constructor·enum block의 root/app SDK 일치 |

mock SDK는 실제 전달받은 typed 값과 texture 의존 관계로 픽셀을 계산한다.
Python reference는 별도 유리수 행렬 계산으로 기대값을 만든다. finalizer는 모든
저장 trace의 단조 prefix·데이터 정리·오류 분류·capability 미승격을 다시 검사한다.

FXC 검사는 CSP의 비공개 `ui.fx` 대신 **별도 PS_IN/상수 선언/entry wrapper**를 붙여
본문 문법을 검증한다. 실제 CSP template compile·자동 상수 packing·GPU 실행을
검증한 결과로 사용하지 않는다. 패키지의 앱 내 require 해석도 실제 CSP 확인 대상이다.

baseline471개에서53개 runtime Lua/HLSL,3개 INI,이전 s91–s125 작업332개,
asset hash와 Git HEAD를 보존한다. 기존 변경은 docs index/roadmap뿐이다.
실제 게임 추가 pass0·할당0이며 설치·reload·commit/push·반복 로그 요청을 하지 않았다.

## 5. 실제 실행 시 사용할 순서 — 이번 단계에서는 실행하지 않음

독립 앱을 사용할 수 있는 통제된 CSP 세션에서 패키지의 앱 폴더를 별도로 배치한다.
RealVisor 본체를 교체하지 않는다. 앱 창을 열고 Enable → Run one-shot probe 순으로
실행한다. pending 중 앞 pass가 반복되지 않는지, 최종 classification과 채널 값이
기대값과 맞는지 확인한다. Log probe report에서 상태와 전체128개 값을 얻을 수 있다.
재실행이 필요하면 독립 probe 앱의 수명을 새로 시작해야 한다.

다음 작업은 실제 CSP 관찰 결과와 local 기대값을 대조해 **확인한 API 범위만** 기록하는
단계다. 이후에 lifetime/완료 정책과 live source·geometry·pose provider가 확보돼야 queue와
full transport graph를 연결할 수 있다. 저비용 정확도·물리 closure·공통 광학·목표 비용
검증은 계속 남아 있다.

## 6. 재현

```text
docs/tools/audit_s126_probe_sdk.py
docs/tools/check_s126_probe.py
docs/tools/finalize_s126.py
```

결과·shader shim·압축 trace·실행 ZIP·baseline·source diff·delivery:
`docs/diagnostics/2026-10-17/s126/`.
