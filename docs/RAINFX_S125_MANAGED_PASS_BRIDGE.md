# RainFX s125 — managed canvas pass bridge

Date: 2026-10-17
Status: ACTIVE — offline Lua implementation; CSP adapter uninstalled and gated

## 1. 범위와 현재 게임 상태

s124 다음 작업인 **고정 schema의 managed canvas pass bridge**를 구현했다.
게임 물리는 **s87**, 진단은 **s89** 상태다. s91 이후 수송 후보는 계속 offline이며
이번에도 게임 파일 설치·reload·사용자 설정·재질·KN5 변경은 없다.

`docs/tools/s125_managed_bridge.lua`는 고정 pass graph와 canvas를 소유한다.
실제 API를 호출하는 `M.csp(...)` adapter도 작성했지만 앱에서 require하지 않는다.
adapter의 `logicalOrdered`와 `physicalCompletion` 능력은 모두 기본 false다.
실제 CSP ordering을 확인하기 전에는 `begin()`이 `ordering_unverified`로 멈춘다.
**s124 queue의 strict-completion gate는 그대로 유지한다.**

이번 graph는 균일값 생성 → 전체 canvas shader copy → 값 변환의 작은 계약 fixture다.
물리 수송·P2/P3 물량 공급·실제 공간 provider를 연결한 것이 아니다.

## 2. 구현한 계약

### 고정 params와 입력 보유

- 최대32개 resource/pass, 명시적인 nominal byte 한도 내에서 한 번 할당한다.
  현재 형식은 RGBA32F·1mip·AA 없음이며 descriptor 전체를 할당 전에 검사한다.
- resource마다 정확히 한 pass가 전체를 쓴다. texture 입력은 앞서 생성된 canonical
  whole canvas 또는 명시적 `false`만 허용한다. imported texture/mip view는 받지 않는다.
  full-target write·discard 없는 shader인지는 backend/recipe 작성자의 의무다.
- pass별 params/textures/values/defines **table identity와 키·형식**을 유지한다.
  shader/include 변경 시 recipe 작성자가 cacheKey를 갱신해야 한다.
- number/boolean/vec2/vec3/vec4/mat4x4 입력을 모두 검증한 뒤 소유한 값으로 만든다.
  생산자의 숫자 배열이나 recipe를 이후 변경해도 pending pass가 바뀌지 않는다.
- matrix는 row-major 숫자16개를 `mat4x4(vec4,vec4,vec4,vec4)`로 구성한다.
  일반 values 자동 배치를 사용하므로 **수동 transpose와 directValuesExchange는 없다**.
  실제 shader에서의 방향/배치는 아직 CSP probe로 확인해야 한다.

GPU texture 자체를 외부 producer로부터 복제·freeze하는 기능은 이번 범위에 없다.
모듈이 생성하고 외부에 노출하지 않는 canvas만 사용한다. provider와 그 소비자가
뒤에서 texture를 수정하거나 dispose한다면 이 소유권 계약은 성립하지 않는다.

### shader 보류와 prefix

`pump(token, budget)`은 pass 예산 안에서 순서대로 제출한다. `false` 반환을 받은
pass는 진행하지 않고 `shader_pending`으로 보유한다. 이미 true를 받은 앞부분은
다음 pump에서 다시 실행하지 않는다. 예를 들어 pass1=true, pass2=false이면 다음은
pass2부터 재개한다. 이를 s124의 "전체 시도에 제출이 없었음"으로 보고하지 않는다.

예외나 boolean 이외 반환은 **제출 여부 불명**으로 다룬다. 이미 GPU 작업이 있었을
수 있으므로 fault 상태로 자원을 보유한다. CSP의 일부 shader 예외는 Lua pcall로
복구되지 않을 수 있다. 이번 pcall이 게임의 모든 compiler/device 오류를 회복한다는
뜻은 아니다.

`copyFrom`은 source가 없거나 dispose되어도 target의 옛 내용이 남을 수 있고 반환값이
성공 여부가 아니다. 이번 whole-canvas copy는 같은 크기/형식을 검사한 뒤 별도 `Load`
shader pass로 표현한다. 추가 draw의 실제 비용과 CSP compile은 아직 측정하지 않았다.

### 논리 게시와 물리 완료

모든 pass가 제출된 뒤 `publish()`가 root **메타데이터**를 한 번 갱신한다.
이는 확인된 동일 backend의 순서 제출 능력을 전제로 한 논리 게시다.
GPU 완료·CPU readback·수송 시간/물량의 commit을 뜻하지 않는다.
root snapshot은 resource 번호만 담고 canvas handle을 렌더 소비자에 내보내지 않는다.

자원 재사용에는 별도의 신뢰된 backend 완료 관찰과 `retire()`가 필요하다.

1. 일부라도 제출됐거나 제출 여부가 불명인 작업은 cancel/reset에도 보유한다.
2. reset은 generation을 올리고 old 작업의 새 게시를 차단한다.
3. `complete` 관찰 전에는 retire와 dispose를 차단한다.
4. 완료됐어도 논리 root가 남으면 retire를 거부한다. `unpublish` 후에만 재사용한다.
5. 완료 능력이 없으면 경과 frame/time으로 대체하지 않는다. opt-in mock ordering만
   켠 경우 한 작업 뒤 bounded hold 상태로 머물며 새 canvas를 계속 할당하지 않는다.

완료 신호는 **모든 실제 소비자의 마지막 사용까지 포함**해야 한다. 이번에는 실제
렌더 소비자가 없으며, future adapter가 마지막 writer만 관찰하고 외부 scene reader의
종료를 무시해서는 안 된다. device failure의 안전한 폐기/복구도 여전히 미구현이다.

## 3. 검증 결과

실제 LuaJIT 모듈을 실행하고 Python의 별도 metadata/스칼라 canvas 모델과 매 동작
대조했다. fake backend는 pass별 table identity·키·형식·texture alias를 검사하고,
실제 전달받은 uniform 값과 draw 시도만 기록한다. 이는 HLSL/GPU 수치 oracle이 아니다.

| 항목 | 결과 |
|---|---|
| 시나리오 / 동작 | **16 / 6,271** |
| recipe·allocation·producer 입력 오류 방어 | **21** |
| pending/값 보유 시나리오 |13회 작업·39회 accepted draw·3회 pending; 앞부분 중복 실행 없음 |
| 무작위 실행 |6,000회 선택 후 정리 포함;218회 작업,241회 accepted draw,106회 pending |
| random reset / 완료 후 retire |510 /111회 |
| 고정 할당 |시나리오별 canvas3개; pump/begin/reset에서 새 할당0 |
| fixture nominal canvas payload |8×4×16byte×3 = **1,536byte** |
| SDK 근거 |**11개** API/생성자/enum block이 root/app SDK와 일치 |

prefix 중간 보류·재시도, producer/recipe 변조, 모든 uniform 형식, boolean false,
false texture placeholder, 제출 전/후 cancel/reset, 조기 complete·stale token,
root 보유 중 retire 거부, 예외·불명 반환·실패 뒤 늦은 완료, 미지원 capability,
canvas 사용 불가 및 게시 직전 사용 불가, source/target alias·copy 크기·byte 한도를
검증했다. 할당 도중 실패/identity 충돌에서도 이미 생성한 fixture canvas를 정리했다.

별도 finalizer가 저장된 모든 trace를 다시 읽어 모델 결과와 상태를 대조하고,
원본53개 runtime Lua/HLSL·3개 INI·이전 s91–s124 파일326개와 Git HEAD/asset hash를 검사한다.
baseline465개 중 기존 변경은 docs index/roadmap뿐이다.

**미검증:** 실제 CSP shader compile/상수 배치·행렬 방향·ordered canvas visibility·
GPU 완료/retirement·GPU/CPU ms·VRAM·게임 FPS·장시간 메모리.1,536byte는 fixture의
계산상 texel payload이며 실제 driver 할당이나 게임 메모리 수치가 아니다.
게임에 새 pass0개·추가 할당0byte, commit/push와 반복 로그 요청도 없다.

## 4. 다음 구현

다음은 full transport 이식 전에 사용할 **독립적인 작은 CSP probe 패키지**다.

- uniform/row-matrix 방향을 구분할 비대칭 패턴과 whole-copy/readback 기대값을 만든다.
- 동일 callback 안의 의존 pass와 pending prefix를 실제 managed canvas에서 관찰한다.
- app 기본 경로와 분리하고 기본 OFF로 두며, 결과가 준비됐다는 이유로 strict fence
  능력을 켜지 않는다. `accessData`의 데이터 관찰과 일반 completion 증명을 구분한다.
- CPU callback 반환·typed value 보유·disposal 제한의 확인된 범위를 기록한다.

검증된 lifetime 정책과 공급/geometry/pose 소유권이 확보된 뒤 queue와 full graph를
연결한다. 저비용 정확도 제어·물리 closure·head/film 공통 광학·실제 비용 채택 조건도 남는다.

## 5. 재현 및 파일

```text
docs/tools/audit_s125_bridge_sdk.py
docs/tools/check_s125_bridge.py
docs/tools/finalize_s125.py
```

Lua 모듈: `docs/tools/s125_managed_bridge.lua`.
독립 oracle: `docs/tools/s125_bridge_reference.py`.
증거: `docs/diagnostics/2026-10-17/s125/`의 SDK audit, bridge report,
scenario별 압축 trace, baseline, source diff, delivery.
