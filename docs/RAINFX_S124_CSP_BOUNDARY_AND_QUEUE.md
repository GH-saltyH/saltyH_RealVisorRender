# s124 — CSP 연결 경계 감사와 보존 입력 대기열

2026-10-17. **Status: ACTIVE — 로컬 SDK 감사·오프라인 Lua 호스트 프로토콜.**

게임 물리는 s87, 진단은 s89다. 이번 단계는 공개 SDK 기능을 확인하고 호스트 입력
대기열을 구현했다. 새 수송 shader·CSP 렌더 callback·게임 설치는 추가하지 않았다.
실제 GPU 완료 신호와 새 모델의 CSP 실행 수명은 아직 검증되지 않았다.

## 1. 로컬 SDK에서 확인한 연결 경계

권위 있는 대상은 `lights-patch-v0.3.0-preview634/extension/internal/lua-sdk/ac_apps/lib.lua`다.
루트 `lib.lua`와 파일 전체는 다르지만, 이번에 사용한15개 API의 선언·설명은 일치한다.
두 파일과 생성 README, SDK 안내/경로 규칙의 해시를 함께 보존한다.
전체2089개 함수 선언을 조사했으며 증거 원문/행 번호는 `s124/sdk_audit.json`에 있다.

| 기능 | 확인한 API/계약 | 첫 연결 구현의 선택 |
|---|---|---|
| 영구 float target | `ui.ExtraCanvas(resolution,mips,AA,format,flags)`, `memoryFootprint`, `dispose` | 고정 크기·명시적 float format의 managed canvas bank를 유지 |
| offscreen 계산 | `updateWithShader(params)` | `async=true`; 준비되지 않아 반환한 `false`를 처리하고 진행 위치를 보존 |
| scene-aware offscreen | `updateSceneWithShader(params)` | 카메라/광학용과 수송 계산용을 구분 |
| 상수·텍스처 | `params.values/textures`, 자동 정렬, 동일 table 재사용 권고 | 고정 키·형식 schema와 구간별 소유 값으로 전달 |
| 직접 값 교환 | `directValuesExchange=true`이면 values가 FFI 구조로 교체됨. matrix 수동 transpose 필요 | 첫 bridge는 일반 values 사용. 직접 교환은 별도 수명/배치 검증 후 평가 |
| whole-image copy | `ExtraCanvas:copyFrom(other)` | bank parent 직접 참조를 우선 검토. region copy가 필요하면 shader 경로의 추가 비용 평가 |
| readback | `accessData(callback)`는 비동기 CPU 데이터 전송 | 진단용. 일반 GPU 완료/자원 retirement 증명으로 대입하지 않음 |
| timing | `render.measure(key,drawFn,...)` | boolean 결과를 별도 지역 변수로 캡처해 compile-pending 반환을 유지 |
| 실행 위치 | `render.onSceneReady`, `render.on(eventName,callback)` | 하나의 소유 callback/진행 커서와 별도 render-view guard 필요 |
| pause | `ac.getDeltaT()`는 sim/replay pause에서0 | 0시간 구간은 신규 공급·시간 진행 없이 처리 |
| image readiness | `ui.isImageReady`, `ui.onImageReady`는 image loading readiness | GPU 쓰기 완료 신호로 사용하지 않음 |

SDK의 `updateWithShader` 설명에서 **async는 shader compilation**을 뜻한다.
`false`는 준비되지 않아 그 호출의 draw가 일어나지 않았다는 의미다. `true`를
네이티브 event query의 물리적 GPU 완료와 동일시할 근거는 이 문서에 없다.
전체 그래프 앞부분이 이미 실행됐다면, 뒷부분의 `false`만 보고 전체 작업을
“아무것도 제출되지 않음”으로 분류해서도 안 된다. prefix 진행/자원 소유권이 필요하다.

점검한 공개 app 선언에는 raw `CreateBuffer`, `UpdateSubresource`,
`CopySubresourceRegion`, `GetData`, 일반 fence/constant-buffer API가 없다.
이는 **해당 로컬 공개 Lua 선언에 관한 결론**이며 CSP 내부 전체의 기능 부재를
증명하지 않는다. `sharedHandle`은 공유 texture 접근 식별자이고, 그 설명만으로
Lua에서 D3D device/constant buffer/fence를 직접 제어할 수 있다고 보지 않는다.

따라서 s123의 raw byte 배치·상수 버퍼 pool·fence 수명은 CSP에 그대로 이식하지 않는다.
상수는 CSP의 named values에 맞춰 전달하고, 자원 생성·소유권은 CSP managed canvas에
맞춰 설계한다. 물리적 완료와 논리적 제출/게시의 계약은 구분해서 검증한다.
프레임을 몇 번 기다린 뒤 완료로 간주하는 fallback은 추가하지 않았다.

### 바인딩 한도 대조

`updateWithShader`의 문서상 한도는32 textures다. 기존 s123의41개 compiled program을
DXBC/RDEF에서 읽은 최대 texture 바인딩은16개로 이 한도 안에 있다.
이 확인은 현재 frozen shader 조합에 한정한다. CSP template에서 다시 컴파일했을 때의
타입/정렬·implicit resource·scene texture·실제 실행 비용까지 통과했다는 뜻은 아니다.
고정키 params도 include 변경을 반영한 cacheKey와 별도 사전 검증이 필요하다.
Shader compile 오류는 SDK 설명상 스크립트 중단을 일으킬 수 있으므로 pcall만으로
완전 복구를 약속하지 않는다.

## 2. 구현: 소유권이 있는 정수 tick 대기열

`docs/tools/s124_interval_queue.lua`는 CSP/FFI 호출이 없는 LuaJIT 모듈이다.
고정 크기 ring에 입력 scalar와 식별자를 복사한다. queue 자체에는 GPU texture,
mutable vector/matrix 또는 날씨 구조 참조를 저장하지 않는다.

입력은 다음을 포함한다.

- `generation/sampleId`, 연속된 `startTick/endTick`, 명시적인 `inputMM3`.
- `sourceKey`: 해당 구간의 불변 공급 자료 식별자.
- `geometryKey`: topology/calibration revision. 같은 generation 안에서 변경하면 거부.
- `poseKey`: 구간별 자세·world transform 자료 식별자. 일반적인 자세 변화는 별도 구간으로 허용.
- `settingsKey`, 고정12개 forcing scalar: rain/wetness/water/humidity, Kelvin 기온,
  공기밀도, world 상대풍3성분과 관성가속도3성분.

식별자는64자리 hex label이며 payload를 암호학적으로 인증하지 않는다. 연결할 provider가
실제 geometry/pose/source GPU 자료의 불변 소유권을 유지해야 한다. 여기서는 scalar와
identity snapshot만 시험했다. 공간별 공급·DSD·head 자료를 복제하거나 새 물리 유입량을
계산하지 않는다. `inputMM3`는 fixture/호출자가 제공하는 제어 원장 값이다.

Tick은 공통 정수 시간 단위다. 현재 모듈은 seconds→ticks 변환이나 fractional remainder를
구현하지 않는다. live producer는 같은 generation의 시간 기준과 나머지 누적을 보장해야
한다. float dt를 프레임마다 독립 반올림해 시간을 잃는 방식은 연결 완료 조건이 아니다.

### 공급과 시간 진행은 별도 원장

기존 s95+ 프로토콜은 구간의 공급을 먼저 staging하고, 수송이 거부되면 전체 시간 부채를
유지할 수 있다. 따라서 “진행한 시간 비율만큼 공급이 반영됐다”로 계산하지 않는다.

게시 receipt는 `advancedTicks`와 `stagedSource`를 별도로 갖는다.

1. `stagedSource=true, advancedTicks=0` 체크포인트는 공급 전체를 한 번 기록하고
   시간 부채를 그대로 유지한다.
2. 이후 부분/전체 수송은 `stagedSource=false`로 같은 공급을 재적용하지 않는다.
3. 잘못된 epoch, identity, 진행량, 재공급 또는 공급 없이 진행하는 receipt는 거부한다.
4. 호출자가 실제 root bundle을 게시했다고 확인한 뒤 queue의 epoch/원장을 함께 전진시킨다.

```text
acceptedTicks = committedTicks + abandonedTicks + queuedTicks
acceptedMM3   = committedMM3   + abandonedMM3   + unappliedMM3
```

정수 tick은 정확히 집계한다. mm³ 누계는 compensated double 합산이며, 독립 reference는
입력 float의 exact rational 합계로 대조한다. 이 원장은 호스트 공급/진행 계약이며
물리 field의 증발·유출·반발·운동량 원장을 대체하지 않는다.

### 상태와 수명

| 상태 | 허용 동작 | 유지할 것 |
|---|---|---|
| queued | FIFO head 준비 | 입력별 forcing/pose/source와 남은 시간 |
| prepared | 미제출 compile 대기·retry·취소 | 같은 snapshot/token. 신규 입력으로 교체 금지 |
| submitted | 완료 관찰·취소 요청 | head와 token. 신규 시도 준비 금지 |
| ready | 명시적 finish | 관찰만으로 공급·시간·epoch를 전진시키지 않음 |
| failed/cancelled | 실제 완료 후 discard | ready 전에는 작업 소유권을 해제하지 않음 |
| reset 이후 old submitted | old token의 완료·discard만 | 최대1개 old generation을 격리 보유 |

`submission(false)`는 **그 시도가 전체적으로 아무 GPU 명령도 제출하지 않았을 때만**
사용할 계약이다. 일부 pass가 제출된 뒤 대기했다면 backend가 그 prefix를 보유해야 한다.
모듈의 `observe(complete)`와 `rootPublished`는 신뢰된 backend가 제공하는 입력이다.
이번 테스트의 완료는 mock이며 실제 GPU 완료 증거를 만드는 기능은 없다.

공개 SDK에서 strict completion 수단이 확인되지 않은 상태를 반영해,
`completionSupported` 기본값은 false다. 이 상태에서는 `prepare()` 자체가
`completion_unavailable`을 반환하고 제출 가능한 job을 만들지 않는다.
테스트에서는 별도의 fixture backend 능력을 명시해 상태 기계를 실행했다.

## 3. 포화·중복·pause·reset 정책

- 슬롯 수, 대기 tick, 미반영 공급 mm³의 세 가지 한도가 있다.
- 중복 sampleId, generation 불일치, 시간 gap/역행을 거부한다.
- 포화 시 입력을 **접수하지 않는다**. 호출자는 원래 입력을 보유·재시도한다.
  강풍/공급의 과거를 평균값 하나로 합치거나 신규 frame으로 덮어쓰지 않는다.
- 0시간/0공급은 pause 결과로 반환하고 sampleId·시간·물량을 늘리지 않는다.
  0시간에 양수 공급을 넣으면 오류다. 유효한0 강수·습도·풍속은 유지한다.
- reset은 남은 시간과 아직 반영하지 않은 공급을 `abandoned`에 명시적으로 기록한다.
  이미 반영한 공급을 다시 abandoned에 더하지 않는다. 이는 의도적인 연속성 중단이다.
- 제출 중 reset이면 old 작업을 최대1개 보유하고 그 슬롯도 용량에 포함한다.
  늦게 도착한 old 완료가 새 generation에 게시될 수 없다.

**유한 queue로 무한 과부하의 모든 frame 이력을 보존할 수는 없다.** 실제 게임은 생산을
멈출 수 없으므로 producer backpressure를 감당할 수 없는 경우 명시적인 continuity
fault/reset 정책이 필요하다. 이번 구현의 무손실 계약은 **접수한 입력**에 대한 것이다.
거부 이후 호출자가 버린 frame까지 보존했다고 주장하지 않는다.

Queue의 ring과 old submitted head 보유 수는 한도 안에 있다. 반환한 job copy나 외부
provider의 GPU 자료까지 queue가 소유·제한하는 것은 아니다. 최대256개 슬롯은 API
안전 한도이며 game 기본 설정으로 정한 값이 아니다.

## 4. 검증 결과

실제 LuaJIT 실행 결과를 Python의 list 기반·exact-rational 원장과 대조했다.
모든 동작의 실제 Lua 결과/상태를 압축 JSONL로 저장하고 별도 finalizer가 다시 읽어 검증한다.

| 지표 | 결과 |
|---|---|
| 시나리오 / 동작 | **16 / 15,640** |
| 잘못된 입력·게시 receipt 오류 거부 | **15** |
| 연속 처리 | 2,000구간,20,000tick,200mm³ 전량 게시; 잔여·폐기0 |
| 무작위 동작 | 5,000동작 뒤 잔여 drain 포함;548개 입력 접수 |
| 무작위 시간 원장 | 접수10,900 = 게시2,501 + 명시적 reset 폐기8,399 + 잔여0 tick |
| 무작위 공급 원장 | 접수561.5625 = 게시169 + 폐기392.5625 + 잔여0 mm³ |
| 무작위 retained slots | 최대5 / 설정5 |
| 완료 미지원 | 접수 입력 보유, 준비 serial0·제출 job0·진행0 |

그 외 FIFO의 서로 다른 forcing/pose, producer/반환 job 변조, 공급 staging 후0tick
체크포인트, 부분 재개, 슬롯/시간/공급 포화 뒤 재시도, 중복/pause, 준비 중 취소,
제출 전/후 reset, 완료 전/후 취소, 실패 후 늦은 완료, stale token과 geometry revision
변경 거부를 포함한다. 오류는 이미 접수한 원장을 바꾸지 않는다.

연속 테스트의 Lua GC 전후값은 raw 관찰로만 기록한다. JIT warm-up을 포함한
headless Lua 수치이며 게임 메모리·누수·장시간 plateau 판단으로 사용하지 않는다.
이번 단계에는 shader/GPU 수송 실행이나 game FPS 측정이 없다.

459개 baseline에서53개 runtime Lua/HLSL,3개 INI,320개 이전 s91–s123 작업을 보존했다.
기존 수정은 docs index/roadmap뿐이다. 사용자 튜닝·재질·assets·이전 보고서, Git HEAD를
유지했다. 게임 설치·reload·추가 로그 요청·commit/push는 하지 않았다.

## 5. 다음 구현과 채택 조건

다음은 **CSP managed canvas를 쓰는 고정 schema pass bridge**다.

1. shader 준비/보류 prefix를 보유하는 진행 커서와 불변 입력 binding을 구현한다.
2. 논리적인 ordered submission/publication과 물리적 GPU 완료·retirement를 별도
   capability로 표현한다. 확인되지 않은 native completion을 true로 만들지 않는다.
3. params 키/형식, matrix 전달, source/target alias, 잘못된 `copyFrom` 입력,
   compile-pending을 검증하고 CSP-managed bank의 수명 계약을 확인한다.
4. 작은 연결 probe로 SDK 설명과 실제 동작을 대조한 뒤 full transport 이식을 판단한다.

실제 geometry/pose/source provider 소유권, dt 변환/대기열 포화 대응,
저비용 수송 정확도·물리 closure, head/film 공통 운동·광학, 장치 복구와 목표 GPU
CPU/ms/FPS 검증은 남아 있다. 새 queue가 이를 통과시킨 것으로 취급하지 않는다.

## 6. 재현

```text
docs/tools/check_s124_queue.py
docs/tools/finalize_s124.py
```

SDK 감사: `docs/tools/audit_s124_csp_sdk.py`. Lua queue:
`docs/tools/s124_interval_queue.lua`. 독립 model:
`docs/tools/s124_queue_reference.py`. 증거·trace·baseline·diff·전달 검증:
`docs/diagnostics/2026-10-17/s124/`.
