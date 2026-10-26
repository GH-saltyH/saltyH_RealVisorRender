# RainFX v2 core — M1 구현 (branch `Refactor/rainfx-core`)

2026-10-25. 기준 커밋 `2c192e33`. 설계: [RE2 계획](RAINFX_CSP728_RE2_OPTIMAL_PLAN.md),
착수 계약: [KICKOFF](RAINFX_V2_KICKOFF.md).
**상태: M1 게임 실행 확인(§9), rev3 반영(§10 — 광학 atlas 제거, 해석적 렌즈, 월드 공간 노출), rev4 반영(§11 — CSP 물방울 외형 모델), rev5 반영(§12 — 동공 디포커스, 물리 굴절, 하우징 제거 소스), rev6 반영(§13 — 접촉 합체), rev7 반영(§14 — 물리 분리·검토, 고속 방울 삭제 버그, 물리 디버그), rev8 반영(§15 — 운동 히스테리시스, 프레임 단위 패스), rev9 반영(§16 — 관찰 도구: 슬로모션·흔적·속도 제한 표시, 흔적 손실, 바람 계수), rev10(§17 — Debug 4 절대 속도 구간), rev11(§18 — A 수막 W와 스프레이), rev12(§19 — 평가 기준안·지표·자차 스프레이), rev13(§20 — rev12 판정 반영: 수막 모자이크, 방울 잘림, 보정), rev14(§21 — rev13 판정 반영: 수막 공급 재보정, 스프레이-노면 물), rev15(§22 — rev14 판정: 목표 대부분 통과, 미세 보정), rev16(§23 — 레퍼런스 비교: 산란 베일, 방울 외형), rev17(§24 — 대기/표면 분리 원칙, 산란 축소).** §1–§3의 P3/optics 설명은 rev3에서 대체됐다. 셰이더 수정 후에는 게임 전에 §6의 FXC 검사를 반드시 돌린다
(Lua 셰이더 컴파일 오류는 앱 스크립트 전체를 멈춘다).

## 1. 파일

|파일|역할|
|---|---|
|`rainfx2/init.lua`|코어 객체: 자원·메쉬 복사·입력 변환·패스 실행·그리기·UI·dispose|
|`rainfx2/physics.lua`|(rev7) 물리 전용: 기본값, 입력(가속·공기·비 방향), 셰이더와 1:1 힘·속도 식, 임계 반지름·속도 진단, substep 선택|
|`rainfx2/shaders/seed.hlsl`|(rev7) 물리 시험: 방울 사다리(0.3–2.2 mm)로 상태를 교체|
|`rainfx2/spray.lua`|(rev11) 앞차·자차 스프레이 추정(앞쪽 원뿔, 거리·측방 감쇠 × 속도² × 노면 물)|
|`rainfx2/shaders/metrics.hlsl`|(rev12) 평가 지표: 바이저 32×8 블록 요약(수막 덮임, 방울 덮임, haze) → 2 Hz readback, CSV|
|`rainfx2/weather.lua`|CSP 날씨 → 공급량(순수 함수). mm/h = rainIntensity×100, Marshall–Palmer, 상대속도 플럭스|
|`rainfx2/shaders/common.hlsl`|해시, 메트릭 tap, 힘→UV 속도, `r2Predict`(gather 결정 함수), 이동 패킹|
|`rainfx2/shaders/cells.hlsl`|P1 셀 갱신: 5×5 gather/합체 + 포아송 birth|
|`rainfx2/shaders/claim.hlsl`, `merge.hlsl`|P1b/P1c(rev6) 접촉 합체: 닿은 이웃 중 가장 큰 방울에 흡수(claim → merge)|
|`rainfx2/shaders/field.hlsl`|P2 표면장: 흔적 T, 미세 haze M (경로 수거·전단·증발), W 예약|
|`rainfx2/shaders/optics.hlsl`|(rev3에서 폐기, 삭제 대상)|
|`rainfx2/shaders/source.hlsl`|P3(rev5) 굴절 소스: glass 이전 프레임 사본 − 하우징(깊이 판정), premultiplied 반해상도 + mip(push-pull)|
|`rainfx2/shaders/visor.hlsl`|P4 바이저 합성(mesh.fx): 해석적 방울(rev4: CSP 외형 모델) + 렌즈 셰이딩 + haze, `R2_DEPTH_ONLY` 변형|
|`docs/tools/check_rainfx2_shaders.py`|dwrite.dll의 CSP 템플릿으로 셰이더를 조립해 FXC 컴파일|
|`docs/prototypes/rainfx2_reference.py`|P1/P3 NumPy 참조 구현(실제 du/dv 메트릭)|
|`docs/tools/rainfx2_mock/`|CSP API 스텁으로 init.lua 제어 흐름 검사|

`realvisor.lua` 접점(총 +49행, chunk-level local 추가 없음):

1. `glassFallback` 안: `visorSceneStack('pre')` → **v2 colour** → `visorSceneStack('post')` → **v2 depth-only**.
2. `glassFallback` 바로 뒤: `rainfx2Get`(지연 로드), `rainfx2Arbitrate`(v2 on이면 legacy `RAIN_ENABLED`를 끄고 기억, off면 복원),
   `render.onSceneReady` 1회 시뮬(오프스크린/native 캡처 중에는 건너뜀), `ac.onRelease` dispose.
3. `script.update` 시작부에서 `rainfx2Arbitrate()`.
4. RainFX 탭 맨 위에 v2 UI.

v2 그리기는 glass scene stack 경로에 들어 있다 → `RAIN_VISOR_LAYER`와 `RAIN_VISOR_SCENE_STACK`이 켜져 있어야 한다(기본값).
장면 소스는 stack의 `fallbackSource`(실제 프레임 `dynamic::hdr` RGBA16F + 전체 mip)를 그대로 쓴다. 추가 복사와 톤 패스가 없다.

## 2. 프레임 흐름과 비용 구조

```text
onSceneReady (1회/프레임)
  for substep in 1..N (기본 2):  P1 cells 512×128 (S ping-pong) → P2 field 1024×256 (F ping-pong)
  P3 optics 1024×256 → mipsUpdate
main.track.transparent (glassFallback)
  glass pre → P4 colour (AlphaBlend, depth RO) → glass post → P4 depth-only (depth write where cov > 0.35)
```

- readback 0, 정점 업로드 0, 방울별 Lua 0. updateWithShader 호출은 2N+1회/프레임, render.mesh는 2회/뷰.
- P1은 25개 소스에 대해 `r2Predict`를 다시 계산한다(텍스처 load 약 150회/셀). 측정 결과 비싸면
  셀별 메트릭 사전계산 텍스처 1장으로 줄이는 것이 첫 최적화 후보다.
- 비용 확인: Render Stats의 `RainFX2 sim`, `RainFX2 draw`.

## 3. 상태 형식

|자원|형식|채널|
|---|---|---|
|S (cells)|RGBA32F 512×128 ×2|x,y 셀 내 위치 · z 체적 mm³ · w 마지막 이동(셀) 패킹 `r2PackMove`(정수, fp32에서 정확)|
|F (field)|RGBA16 UNorm 1024×256 ×2|T 흔적 · M haze · W 수막(예약) · A 유효|
|O (optics)|RGBA16F 1024×256 + mips|R 높이 mm · G 커버리지 · B M · A T|

**속도는 저장하지 않는다**: 종단속도 모델(메모리리스)이라 gather하는 모든 셀이 같은 입력으로 같은 예측을 계산한다.
템플릿 출력이 `float4 SV_TARGET`이라 UInt 렌더타깃은 쓰지 않는다.

## 4. 물리·입력 (SI, 오브젝트 축 / 월드 미터)

- `updateInputs`: GLASS_RAINFX 월드 행렬의 역행렬로 월드 벡터 → 오브젝트 축, ×profile scale.
  가속 = 중력 − 차량가속(car.acceleration 로컬 G → 월드 ×9.81). 공기 = 바람(windVelocityKmh) − 차량속도.
  비 상대속도 = (0,−v_t,0) + 공기.
- 힘: m·g_t + ¼ρC_dπr²|u_t|u_t (u_t = 표면 접선 공기 × `airSurface`). 고착 임계 0.072·2r·Δcos·noise(셀),
  Δcos는 코팅(dv.A) 0.18 / 맨유리 0.35. 이동 속도 v = (|F|−F_pin)/(friction·r), 상한 vMax.
- UV 투영: (JᵀJ)⁻¹Jᵀv (J = du, dv × scale). 도착 셀 무효(du.A<1 또는 mask.A<0.5)면 흡수.
  한 서브스텝에 2셀 이상 움직이면 바람에 날린 것으로 보고 제거(shed).
- birth: λ = impactRate · 셀면적(|du×dv|) · 노출(−n·rainDir) · exposure · dt.
  지름은 지수 DSD(평균 D)로 샘플하고, 일부(stick)만 남긴다. 기존 방울과 겹치면 합체한다.
- 노출 판정은 마스크 object normal을 쓴다. 비가 엉뚱한 면에 붙으면 UI의 **Flip surface normal**로 뒤집는다.

이 KN5의 오브젝트 축(측정값): x = 가로, z ≈ V 방향(세로), y = 깊이. 실제 방향은 월드 행렬이 처리하므로 코드에 하드코딩하지 않는다.

## 5. 기본값 (첫 추정, 게임 튜닝 대상)

|그룹|값|
|---|---|
|격자|cells 512×128 (≈1.18×1.14 mm), field/optics 1024×256, substeps 2|
|공급|v_t 6 m/s, exposure 0.5, stick 0.8(저속)→0.4(고속), microK 6, sprayFlux 2e-5(M1은 스프레이 0)|
|방울|shapeK 2.094(반구), friction 0.06, airSurface 0.35, Cd 1, vMax 1 m/s, trailLoss 0.02, evap 1e-4 mm/s, r 0.08–2.5 mm|
|field|microEvap 0.05/s, microShear 0.02, microCollect 0.9, traceDecay 0.6/s, traceAmount 0.6|
|광학|minDraw 0.35 mm(서브텍셀 방울을 면적 보존으로 그림), edge 0.15 mm|
|합성|defocus LOD 1.5, refract 300, dropMip 1.5, hazeMip 4, hazeK 0.8, veilMix 0.25, depthCoverage 0.35|

`friction`과 `airSurface`는 NumPy 참조 검사에서 정했다(§6). friction 330(초기 추정)으로는 60 m/s에서도 방울이
0.1 mm/s로 기어가서 B의 닦임이 나오지 않았다. airSurface 0.1에서는 고속에서도 거의 모든 방울이 고착됐다.

## 6. 검사와 결과

|검사|결과|
|---|---|
|Lua 구문(texlua 5.3 load): init.lua, weather.lua, 패치된 realvisor.lua|통과|
|CSP API mock 실행(`docs/tools/rainfx2_mock/run_mock.lua`, texlua/Lua 5.3): 3프레임 시뮬 → colour/depth 그리기, view-key 중복 방지, 자기 타깃 읽기 없음, nil 값 없음|통과|
|셰이더 조립(`check_rainfx2_shaders.py --emit-only`): 5개 변형|생성 확인. **FXC 컴파일은 사용자 PC에서 실행 필요**|
|NumPy 참조(실제 du/dv, 600프레임, substep 2)|아래 표|

|장면 입력|방울 수|이동 중|shed|r p50/p95 (mm)|커버리지|
|---|---|---|---|---|---|
|C: 2 mm/h, 15 m/s|1237|0|0|0.19 / 0.54|0.2%|
|B: 8 mm/h, 60 m/s|4457|15 (평균 6 cm/s)|1|0.18 / 0.53|0.6%|
|A: 40 mm/h, 55 m/s|6228|37 (평균 14 cm/s)|6|0.21 / 0.68|1.7%|

- 이동 단계의 체적 수지: 입력 대비 이동 후 차이는 흔적·증발·가장자리 이탈뿐이다(예: B 287.82 → 287.66 mm³).
- UV 섬·구멍·가장자리에서 방울이 흡수되고, 고속에서는 정면 노출부에 충돌이 집중되며, 아래 가장자리에 흘러내린 물이 모인다
  (`tmp/rainfx2_ref/*_optics.png`).
- 해석: C는 고착된 작은 방울(목표와 일치). B는 움직일 수 있는 방울이 빠르게 쓸려 나가고 작은 고착 방울 + haze가 남는다.
  A는 커버리지가 부족하다 → 수막 W와 스프레이(M3)가 필요하다는 기존 판단과 일치.

## 7. M1 게임 확인 순서

1. `python docs/tools/check_rainfx2_shaders.py` → 5개 모두 OK인지(실패 시 `tmp/rainfx2_shaders/*.log`).
2. 앱 reload → RainFX 탭 상단 상태가 `running`인지. `compiling ...`이 계속되면 log 확인.
3. 비 날씨에서 Debug view 1 → 빨강(방울)·초록(haze)·파랑(흔적)이 바이저 정면에 생기는지. 반대 면이면 Flip normal.
4. Debug 0으로 돌려 밴드·하우징이 방울을 가리는지, depth 패스 뒤 차량 유리·와이퍼가 방울 위에 블렌드되지 않는지 확인.
5. Render Stats `RainFX2 sim` / `RainFX2 draw` GPU·CPU ms 기록. 목표 GPU ≤0.5 ms @1440p, CPU ≤0.1 ms.
6. 같은 리플레이로 C(약비 저속) → B(중간비 고속)를 비교하고 refraction / defocus / haze 슬라이더로 첫 튜닝값을 기록.

## 8. 아직 하지 않은 것

- A 장면: 수막 W(저주파 흐름 노이즈 굴절), 앞차 스프레이 추정.
- CSP 화면 방울 opt-in 끄기(설정 백업/복원). 그 전까지는 CSP `rain_fx.ini [SCREEN_DROPS] STYLE_COCKPIT=NONE`을 수동으로 권장.
- 미러 water-only 패스, `txPreviousFrame`을 써서 복사를 줄이는 실험, P1 사전계산 최적화.
- legacy 일괄 삭제(R2)와 공유 인프라 개명(R3).

## 9. M1 게임 결과 (사용자, 2026-10-25)와 rev2

|항목|결과|
|---|---|
|FXC|5개 변형 모두 컴파일. 경고 1종(`pow` 음수 base, `r2RadiusMM`)|
|실행|상태 `running`. 정지 상태 5 mm/h에서 방울이 하나씩 붙어 쌓임|
|가림|카메라에 더 가까운 하우징이 방울을 정상적으로 가림|
|비용 (RTX 3070)|Frame preparation `RainFX2` **0.23 GPU ms**, Main pass Transparent `RainFX2` **0.07 GPU ms**, 합계 0.30 ms (목표 ≤0.5 ms)|

정합성 평가:

- **좋은 점:** 방울이 시간에 따라 하나씩 쌓이는 C 장면의 기본 거동, 하우징 가림 순서, 비용 예산이 맞다.
  하늘 배경에서는 방울이 어두운 테두리 + 밝은 내부의 작은 렌즈로 보인다. 균일한 하늘에서는 굴절된 상의 차이가 거의 없어 테두리만 두드러진다.
- **결함 1 — 방울 모양이 잘린 얼룩처럼 보임(debug 1):** 광학/표면장 패스가 주변 3×3 셀만 봐서, 반지름이 1셀을 넘는 방울
  (최대 2.5 mm ≈ 2셀)의 원판이 탐색 창 경계에서 잘렸다. → **5×5로 확대, 최대 반지름 2.2 mm**.
- **결함 2 — 노출면 판정 불확실:** 베이크된 object normal의 부호를 믿을 수 없었다(Flip 토글로 수동 판단).
  → **자동 판정**: 눈(카메라) 위치를 KN5 로컬로 변환해 `position.dds`와 비교하고, 눈 반대쪽을 외부면으로 본다
  (`r2Exposure`). 토글은 수동 반전(`Invert exposure side`, 기본 off)으로 바꿨다(이전에 저장된 flip 값은 쓰지 않음).
  **Debug 2** = 노출 지도(빨강: 비가 닿는 면, 파랑: 가려진 면).
- 참고: 메쉬가 한 장이므로 바이저의 어느 쪽에서 보든 방울이 보이는 것은 정상이다. 판정해야 할 것은 *어느 면적에 비가 붙는가*이고,
  이는 Debug 2와 주행 중 정면 집중으로 확인한다.
- 경고 제거: `r2RadiusMM`을 `exp2(log2(v/k)/3)`로 바꿨다.
- 외부(3인칭) 화면에서는 밴드가 물 위에 그려진다. 콕핏 전용 순서 계약(§1)의 결과이며, 외부 뷰 대응은 범위 밖이다.

rev2 비용 영향: field/optics의 셀 탐색이 9 → 25(이 두 패스만 약 2.8배). 0.23 ms 중 P1(25 소스 재예측)이 대부분이라
전체 증가는 작을 것으로 예상하지만 다시 측정해야 한다.

다음 확인(rev2):

1. FXC 검사 → 경고 0인지.
2. Debug 2: 정지 상태에서는 위쪽을 향한 면이, 주행 중에는 정면이 빨간지. 반대로 나오면 Invert 토글로 확인한 뒤 보고.
3. Debug 1: 방울이 둥근 원판으로 보이는지.
4. 실제 배경(트랙, 차체)이 보이는 방향에서 Drop refraction 600–900을 시험해 렌즈 상이 드러나는지.
5. 같은 Render Stats 항목으로 비용 재측정.

## 10. rev2 게임 결과와 rev3 (2026-10-25)

|항목|rev2 결과|
|---|---|
|FXC|경고 0|
|Debug 2 노출|정지 상태에서 yaw만 바꿔도 빨강/파랑 경계가 움직이고, 하늘을 봐도 방향에 따라 파랑 → **눈 위치 판정이 틀림**. 주행 중 정면→측면 그라디언트는 정상|
|Debug 1 모양|불규칙한 얼룩 모양 유지|
|렌즈 상|경계가 거의 안 보이고 문질러진 블러 느낌. 렌즈 상이 드러나지 않음|
|비용|Frame preparation 0.29 ms, Events 0.08 ms|

원인과 조치:

1. **노출 판정:** 사용자 확인 — 베이크된 노멀은 실제 바깥면을 향한 object space다. 눈 위치 판정을 폐기하고 baked normal을
   그대로 신뢰한다. 또 Lua에서 하던 월드→로컬 변환(`mat4x4:inverse():transformVector`)을 없애고, legacy 솔버에서 검증된
   셰이더 규약 `mul(v, (float3x3)gR2ObjToWorld)`(CSP가 행렬을 HLSL용으로 전치)로 로컬 법선·du·dv를 월드로 올린다.
   모든 힘·노출 계산은 월드 공간에서 한다(`gR2AccelW`, `gR2AirW`, `gR2RainDirW`). `txR2Pos`, `gR2EyeObj` 삭제.
2. **얼룩 모양과 블러:** 근본 원인은 해상도다. 1024×256 광학 atlas는 0.59 mm/texel인데, 눈에서 수 cm 거리의 1 mm 방울은
   화면에서 수십 px로 확대된다. 그래서 방울이 2–3 texel의 덩어리로 보였고, mip 디포커스가 경계를 더 문질렀다.
   → **P3 광학 패스와 atlas/mip을 삭제**하고, 바이저 픽셀 셰이더가 셀 상태 5×5에서 방울 원을 **해석적으로** 계산한다
   (해상도 무관, 패스 1개·밉 생성 1회 절약). 디포커스는 경계 부드러움(`edgeSoftMM`)과 장면 mip으로 표현한다.
3. **렌즈 광학:** legacy head/micro의 plano-convex 규칙(사용자가 충실하다고 평가)을 자산화했다.
   돔 h = R(1−(r/R)²), 무차원 기울기 s = −2(r/R)/K²(K=1.24). UV Jacobian(ddx/ddy)으로 화면 방향을 구하고,
   오프셋 = s × refraction(0.69 shot height) × (aspect, 1)로 **중심을 지나쳐 샘플**한다(반전·축소 상).
   mip = dropMip + 1.5·sat(|s|/1.5). 림 에너지 손실 0.75 (|s| 0.7→1.3). 위를 향한 림에 하늘색 글린트 0.45·facing⁴.
   배경 휘도 대비 0.55–1.45 톤 창(floor 0.25×fog). CSP DISTANT 화면 방울(반전 샘플 + bias 2)과도 같은 계열이다.
   - UI: `Lens refraction`(0–1.5, 기본 0.69), `Drop edge softness / defocus`(mm). 이전 저장값(`refractPx`, `defocusLod`)은 쓰지 않는다.

남은 파일 정리: `rainfx2/shaders/optics.hlsl`은 더 이상 로드하지 않는다(삭제 대상). NumPy 참조(`rainfx2_reference.py`)의
optics 부분은 rev3 visor 계산과 다르다(P1 검증용으로만 유효).

rev3 확인:

1. FXC 4개 변형(cells, field, visor, visor_depth) OK.
2. Debug 2: 정지 상태에서 위를 향한 면이 빨강이고, 머리를 돌려도 *같은 면*이 빨강으로 유지되는지.
3. Debug 0: 트랙·차체가 배경일 때 방울 안에 뒤집힌 축소 상이 보이고, 림이 어두우며, 경계가 선명한지.
4. 비용: visor 픽셀당 25 load로 Events(draw) 비용이 늘어난다. 0.08 → ? ms. 1440p에서 0.3 ms를 넘으면
   셀 탐색을 3×3 + 큰 방울 전용 경로로 줄인다. Frame preparation은 optics 패스 제거로 줄어야 한다.

## 11. rev3 게임 결과와 rev4 — CSP 물방울 외형 모델 (2026-10-25)

|항목|rev3 결과|
|---|---|
|FXC|4개 변형 OK, `optics.hlsl` 삭제됨|
|Debug 2|기대대로(같은 바깥면이 머리 회전과 무관하게 빨강)|
|외형|경계·굴절 선명. 일부 방울이 반투명·흐릿(원인 불명)|
|비용(3240×1823, RTX 3070)|main transparent(draw) 0.22 ms, frame preparation 0.16 ms|
|방향|legacy plano-convex 돔은 해상도·블러·모양 다양성·texel 크기별 프로파일링에 손이 많이 든다 → **CSP 물방울 모델의 외형 결정 로직을 모방**. 물리(움직임)는 이번 단계 평가 대상 아님|

### 11.1 CSP 물방울 외형 로직 (preview728 dwrite.dll RE)

|셰이더|외형에 관여하는 부분|
|---|---|
|`accRainMap_dropsStateSpawn_ps`|원판 스탬프: `|uv|` + noise×0.1로 **윤곽을 흔든다**, 양 0.6–1.0|
|`accRainMap_dropsStateUpdate_ps`|mip1에서 5-tap 십자 블러, `G = max(avg, (2R)²) − 0.02` — 높이맵을 **고정 폭으로 부드럽게**|
|`accRainMap_dropsFinalize_ps`|`H = 2R + 0.5(0.1G + B)`, LOD 0/1.5/3(오프셋 0.0005/0.002/0.006)에서 다중 스케일 기울기, 커버리지 `sat(4H)`|
|`pfxWindscreen_ps`|윤곽 반지름 `d·(noise·(v.x+0.6)+0.8)` — 방울마다 다른 유기적 윤곽, 구간별 프로파일|
|`wet_fx` / `wet_fx_wipermask` 재질|t26–t30 바인딩(t27 tiled drops map, texture bombing; t28 triplanar)|

결론: CSP 방울은 **평평한 윗면의 스탬프 + 고정 폭으로 부드러워진 림**이다. 법선(굴절)은 림 띠에 몰리고 윗면은 거의 평평하다.
작은 방울은 림 폭이 반지름을 넘으므로 자연히 돔이 되고, 큰 방울은 "맑은 중심 + 어두운/밝은 테두리"가 된다.
윤곽은 노이즈로 흔들려 같은 원이 반복되지 않는다. 이 구조는 해상도에 의존하지 않고(폭이 mm로 고정), 크기별 튜닝이 필요 없다.

### 11.2 rev4 구현 (visor.hlsl / cells.hlsl / common.hlsl / init.lua)

1. **방울별 시드:** 상태 `w = seed·2²⁰ + packedMove`(`r2PackMove(d, seed)`, `r2UnpackSeed`). 4 bit(16종).
   cells 패스에서 가장 큰 기여 방울의 시드를 이어받고, birth가 기존 부피보다 크면 새 시드. 추가 텍스처·채널 없음.
2. **윤곽:** `rEff = r·(1 + contourAmp·c(θ))`, `c = 0.55 sin2θ + 0.30 sin3θ + 0.15 sin5θ`(위상은 시드에서). CSP noise 반지름의 해석적 대응.
3. **프로파일:** 림 폭 `e = min(bevelMM, rEff)`, `xr = sat((rEff−d)/e)`, `h = hgt·(smoothstep(xr) + domeK·(1−q²))`,
   `hgt = min(r·aspect, maxHeightMM)`. 약한 돔 항(domeK 0.25)으로 윗면 안에도 살짝 반전·축소 상을 남긴다.
4. **기울기:** `s = hgt·6xr(1−xr)/e + hgt·domeK·2q/rEff`, `slopeMax`로 부드럽게 제한. 이후 렌즈 셰이딩(UV Jacobian, 중심 지나쳐 샘플,
   기울기에 따른 mip, 림 에너지 손실, 위쪽 림 글린트, 톤 창)은 rev3 그대로.
5. **반투명 방울 수정:** rev3은 `minDrawMM`(0.35 mm)보다 작은 방울을 면적비 `(r/minDraw)²`로 흐리게 했고, 사용자 저장값
   `edgeSoftMM` 0.53 mm가 경계를 1 mm 넘게 번지게 했다 → 0.1–0.3 mm 방울이 "유령"처럼 보임. rev4: `alpha = sqrt(r/minDraw)`,
   경계 폭도 alpha에 비례. 기본 edgeSoft 0.12 mm 권장(저장값이 있으면 UI에서 내려야 한다).
6. **기본값 (NumPy 미리보기 `tmp/look`로 조정):** contourAmp 0.12, bevelMM 0.25, aspect 0.5, maxHeightMM 1.2, domeK 0.25, slopeMax 1.5,
   edgeLoss 0.50, lossStart 1.00, lossEnd 1.60. 처음 값(bevel 0.35, loss 0.75@0.7–1.3)은 림이 굵은 검은 고리가 됐다.
7. UI: `Contour irregularity`(0–0.4), `Rim bevel width`(0.05–1.5 mm). 둘 다 저장.

### 11.3 레퍼런스 대비 괴리 (rev3 스크린샷 기준, 우선순위순)

|괴리|원인|대응 단계|
|---|---|---|
|작은 방울이 고르게 빽빽 — 크기 분포가 좁다|한 셀 한 방울 + 반지름 상한 2.2 mm, 접촉한 이웃끼리 합체하지 않음|물리 단계: 접촉 합체(이웃 셀 거리 < r₁+r₂면 병합), 큰 방울 경로|
|거품/벌집 격자 느낌|위와 같음 + 셀 간격(1.17 mm)에 맞춰 방울이 정렬|물리 단계|
|방울이 회색·어둡다|톤 창 하한 0.55 + 림 손실 0.75가 넓은 림 전체에 걸림|rev4: 림 폭 0.25 mm, 손실 0.5@1.0–1.6|
|돔 렌즈가 "비눗방울"처럼 보임|전체 돔 프로파일(굴절이 내부 전체에)|rev4: 평평한 윗면 + 림 집중(CSP)|
|A의 수막/스프레이, B의 haze와 닦인 경로가 약함|W(sheet) 미구현, haze M 강도 낮음|sheet W + spray 단계|

### 11.4 rev4 확인

1. `python docs/tools/check_rainfx2_shaders.py` → 4개 OK (Linux에서는 `--emit-only` 조립만 확인함).
2. `Drop edge softness`를 0.12 근처로. 작은 방울이 흐릿한 유령이 아니라 작고 선명한 점으로 보이는지.
3. 큰 방울: 맑은 윗면 + 얇은 테두리(아래쪽 어둡고 위쪽에 하늘빛), 윤곽이 방울마다 다른지.
4. `Contour irregularity`·`Rim bevel width` 슬라이더로 레퍼런스에 가까운 값을 찾아 알려주면 기본값에 반영한다.
5. 비용: 셰이더 연산이 rev3보다 약간 늘었다(atan2·sin 3회, 후보 방울당). draw 0.22 ms → ? ms.

## 12. rev4 게임 결과와 rev5 — 디포커스, 물리 굴절, 하우징 없는 소스 (2026-10-25)

|항목|rev4 결과 (실제 카메라·바이저 위치)|
|---|---|
|FXC|4개 OK|
|작은 방울|선명한 점으로 보이지 않음|
|윤곽|방울마다 불균일(의도대로)|
|레퍼런스 대비|아직 미달. 사용자 설정 refraction 0.41/1.50, edgeSoft 0.14/0.40, bevel 1.49/1.21 mm(최대 근처 → 돔 선호)|
|**결함**|방울이 안쪽 **하우징까지 굴절 상으로 사용**(현재 화면을 소스로 쓰기 때문)|
|비용|가까운 실제 위치 0.36 ms, 이전 구도 0.18 ms|

### 12.1 원인 분석

1. **하우징 굴절:** `fallbackSource`는 glass stack 'pre' 이전에 복사되지만, 하우징(FRAME, BAND_INNER, BODY_FABRIC_TRACE, CAM*)은
   `mat`가 있는 **네이티브 KN5 드로우**(`visorLayerDrawItem`이 건너뜀)라 `dynamic::hdr`에 이미 들어 있다. 방울은 바이저 *바깥*에 있으므로
   꺾인 광선은 월드로 나가지 하우징으로 가지 않는다. rev4 이미지의 "아래쪽이 검은 방울"은 반전된 상이 화면 위쪽 검은 하우징 띠를
   샘플한 결과다(굴절 0.41 × 기울기 1.5 ≈ 화면 높이의 60% 위).
2. **레퍼런스는 디포커스다:** 레퍼런스 카메라는 먼 곳에 초점이 맞고 바이저는 렌즈에서 수 cm다. 무한 초점에서 바이저 위로 투영한
   블러 원의 지름은 **입사동 지름과 같고 거리와 무관**하다. 그래서 B의 방울은 크기가 비슷한 부드러운 반투명 원판(작은 방울은 동공
   크기로 퍼진 희미한 점)이고, 렌즈 상은 흐려지며, 어두운 배경 위에서만 또렷하다. 핀홀 CG 카메라는 이걸 만들지 않는다 →
   "작은 방울이 선명한 점"은 레퍼런스의 모습이 아니다.
3. **굴절 크기:** rev3/4의 `refraction`은 "화면 높이/기울기" 경험값이었다. 물리값은 θ = (n−1)·s(얇은 프리즘), 화면 UV 오프셋 =
   θ / (2 tan(fovY/2)).

### 12.2 rev5 구현

1. **P3 굴절 소스 (`source.hlsl`, `R2:prepareSource`)** — 색 패스마다 1회(viewKey memo), `updateSceneWithShader`로
   `fallbackSource`(glass 이전 프레임, COAT 없음) + `dynamic::depth`를 읽어 선형 깊이 < `housingM`(0.20 m)이면 가중치 0.
   출력 (rgb·w, w), 반해상도 RGBA16F, 전체 mip. 바이저 셰이더는 mip m, m+2.5, m+6을 premultiplied over로 합성(push-pull 구멍 채움):
   하우징 자리는 주변 월드 색으로 채워진다. 실패 시 원본 사본으로 대체(UI에 오류 표시).
   - 깊이 판정 규약은 legacy와 같다(`d>0.99999` 하늘, `ctx.depthReversed` 선택 — 기본 false = legacy
     `RAIN_DYNAMIC_SHOT_TONE_FRAME_DEPTH_REVERSED` 기본값).
2. **동공 디포커스 (`apertureMM`, 기본 1.2 mm):** 픽셀의 동공 footprint 반지름 rb = max(aperture/2, 0.6·픽셀 mm).
   방울별 덮임 f = 원-원 겹침/동공 면적(smoothstep 근사, × min(1, (r/rb)²)). 겹침 중심(축 방향 구간 중점)에서 프로파일 기울기를 평가해
   평균 광선으로 쓴다. 픽셀당 F = Σf, 평균 기울기 Σf·s/F, 분산 → 굴절 상 블러 mip, 림 손실·글린트도 f 가중. 장면 fetch는 픽셀당 1세트.
   aperture 0이면 rev4의 선명한 방울(픽셀 AA만)로 돌아간다.
3. **물리 굴절:** 오프셋 = (n−1)·`refraction`(기본 1.0 = 물리)·|s̄| · `gR2FovK`(=1/(2tan(fovY/2)), `cameraFOV`).
4. 제거: `minDrawMM`/면적 alpha(동공 덮임이 대신함), `edgeSoftMM`(aperture가 대신함), `slopeMip`. 기본 `bevelMM` 1.0(사용자 선호: 돔), `dropMip` 0.5.
5. 저장 키: `refractK`, `apertureMM`(옛 `refraction`/`edgeSoftMM` 저장값은 쓰지 않음). Debug 3 = 굴절 소스 표시(하우징이 지워졌는지 확인).
6. NumPy 미리보기 `tmp/look/look5.py`(C 프레임 배경, aperture 0/1/2): 1.0–1.2 mm에서 B의 부드러운 반투명 방울과 가장 비슷하다.

### 12.3 rev5 확인

1. `check_rainfx2_shaders.py` → 5개(cells, field, source, visor, visor_depth) OK.
2. Debug 3: 하우징(프레임·패브릭·카메라)이 사라지고 주변 월드 색으로 메워졌는지. 하우징 일부가 남으면 `housingM`(init.lua) 상향,
   콕핏(헤일로·스티어링)이 지워지면 하향. 깊이가 반전돼 보이면(전부 지워짐/아무것도 안 지워짐) `ctx.depthReversed` 연결.
3. Debug 0, aperture 1.2: 방울 아래쪽이 더 이상 검지 않은지, B처럼 부드러운 반투명 원판인지. aperture 0/2와 비교.
4. 비용: source 패스(반해상도 + mip) 추가, 방울 판정 반경이 rb만큼 넓어짐. 실제 위치 0.36 ms → ? ms.

## 13. rev5 게임 결과와 rev6 — 접촉 합체 (2026-10-25)

|항목|rev5 결과|
|---|---|
|FXC|5개 OK|
|하우징|굴절 상에서 제거됨(Debug 3 확인)|
|방울 아래쪽|더 이상 검지 않음|
|aperture 0 / 1.2 / 2|0: 선명한 렌즈 방울. 1.2·2: 방울이 적은 곳은 레퍼런스처럼 부드럽지만, **오래 누적된 곳은 규칙적인 격자가 직물 무늬처럼 보임**|
|비용|방울 적을 때 ≈0.30 ms, 가득 쌓였을 때 ≈0.50 ms|

### 13.1 원인

셀당 방울 하나 규칙 때문에 셀 안에서만 합쳐지고, **닿아 있는 이웃 방울끼리는 합쳐지지 않는다**. 오래 누적되면 모든 셀(1.17 mm)이
비슷한 크기의 방울을 하나씩 갖고, 화면에는 셀 격자 그 자체가 나타난다. 디포커스는 이 규칙성을 평균해서 직물 같은 무늬로 만든다.
실제 표면에서는 닿는 순간 합쳐진다(breath-figure 조대화): 크기가 다양해지고 사이에 마른 틈이 생기며, 커진 방울은 미끄러져 길을 닦는다.
비용이 누적량에 비례해 오르는 것도 같은 원인이다(후보 방울 수).

### 13.2 rev6 구현

substep마다 P1 cells 다음에 두 패스(512×128, 각각 5×5 load)를 추가한다:

1. **P1b claim (`claim.hlsl` → C, RGBA16F):** 각 방울이 d < `coalesceK`·(r₁+r₂)인 이웃 중 자기보다 순위가 높은(부피, 같으면 셀 인덱스)
   가장 큰 방울을 하나 고른다. 출력 = 흡수 셀 오프셋, z=1.
2. **P1c merge (`merge.hlsl` → S 핑퐁):** 자기가 claim되지 않았으면 자기 방울을 유지하고, claim이 자기를 가리키는 이웃을 모두 모은다.
   부피 합, 부피 가중 중심(셀 밖 [-0.75, 1.75)까지 허용 → 다음 P1 gather가 재배치), 시드·이동 패킹은 가장 큰 기여자를 따른다. 안정 크기 상한 초과분은 흘러내린다.
3. 연쇄(A→B, B→C)는 프레임에 걸쳐 풀린다(B 셀에 A가 남음). 질량 보존(상한·가장자리 제외).
4. `r2Predict`: 셀 밖 중심을 위해 목적지를 5×5 gather 창 안으로 제한.
5. `coalesceK`(기본 1.0, 0이면 끔)는 init.lua 기본값에만 있다(UI 없음).

NumPy 확인(`docs/prototypes/rainfx2_coalescence_check.py`, 정지 바이저, 탄생 + 큰 방울 낙하만, 600 step):

|조건|방울 수|덮임|r 평균 / p90 / 최대 (mm)|
|---|---|---|---|
|합체 없음 (rev5)|7438|1.00 (포화)|0.64 / 1.25 / 2.20|
|합체 (rev6)|2496|0.25|0.44 / 1.05 / 2.20|

합체 후 분포는 큰 방울과 작은 방울이 섞이고 격자가 사라진다. 단일 merge 질량 오차 1.4%(상한·가장자리).

### 13.3 rev6 확인

1. `check_rainfx2_shaders.py` → 7개(cells, claim, merge, field, source, visor, visor_depth) OK.
2. 오래 누적했을 때 격자·직물 무늬가 사라지고 크기가 다양해지는지(aperture 1.2).
3. 큰 방울이 미끄러지며 길을 닦는지(B의 닦인 경로). 정지 상태에서 덮임이 과도하게 낮으면 `coalesceK`를 0.8로.
4. 비용: sim에 패스 2개 추가(작음), draw는 방울 수가 줄어 0.50 ms보다 낮아져야 한다.

## 14. rev6 게임 결과와 rev7 — 물리 분리와 검토 (2026-10-25)

|항목|rev6 결과|
|---|---|
|FXC|7개 OK|
|장시간 누적(aperture 1.2)|격자는 사라짐. 대신 방울마다 **꽃잎/프로펠러 모양**의 어두운·주황 엽(lobe)|
|움직임|정지 상태(허리케인, 바람 49.8 km/h) 영상: 방울이 거의 움직이지 않고, 경로를 닦는 증거가 확실하지 않음|
|사용자 요구|legacy RainFX와 별개로 **물리량을 검토하고 분리 구현**|
|비용|0.31 ms (rev5 0.50 ms)|

### 14.1 물리 검토 결과

모델(셰이더 `r2DropVelocity`, 이제 `physics.lua`와 1:1): 준정상 미끄럼 v = (F − F_pin)/(c_f·r), F = m·g_t + ¼ρC_dπr²u²(u = 상대 공기 × airSurface),
F_pin = γ·2r·Δcosθ·noise(Furmidge 식), m = ρ·shapeK·r³. 관성 시간이 ms 수준이라 메모리 없는 모델은 타당하다.

수직면 기준 진단(공기는 면을 따라 흐른다고 가정한 상한, coat Δcos 0.18 / glass 0.35):

|상대 공기 km/h|미끄러지기 시작 r (coat)|(glass)|속도 r 0.5 / 1 / 2 mm (m/s, 상한 전)|
|---|---|---|---|
|0|1.12 mm|1.57 mm|0 / 0 / 0.94|
|50|0.71|1.12|0 / 0.28 / 1.68|
|100|0.27|0.51|0.40 / 1.40 / 3.91|
|150|0.13|0.25|1.32 / 3.25 / 7.62|
|200|0.07|0.14|2.62 / 5.85 / 12.8|

- 임계 크기(정지 r≈1.1–1.6 mm, 60–100 km/h에서 1 mm 방울 출발)는 실제 관찰 범위와 맞는다.
- **치명적 결함 (rev1–rev6):** `r2Predict`는 한 step 이동이 1.99셀을 넘으면 방울을 **삭제**했다. 한 step 한계 속도는
  60 fps에서 substep 1: 0.14 m/s, 2: 0.28 m/s, 4: 0.55 m/s. 위 표대로 바람이나 주행 공기가 있으면 거의 모든 움직이는 방울이 이보다 빠르다
  → **움직이기 시작하는 순간 사라졌다.** 영상에서 남은 것은 붙어 있는 작은 방울뿐이고, 경로가 거의 안 보인 원인이다.
- 사용자 화면의 `rel. speed 38 m/s`(≈137 km/h)는 Pure Planner 바람 49.8 km/h와 맞지 않는다. `windVelocityKmh` 해석을 확인해야 한다 →
  rev7 UI에 차 속도·바람 벡터·`windSpeedKmh`·상대 공기를 나눠 표시한다.
- 마찰 c_f 0.06은 r 2 mm 정지 미끄럼 0.94 m/s를 준다. 실제(코팅 면 수 cm/s–0.5 m/s)보다 빠를 수 있다 → 사다리 시험 후 조정 후보.

### 14.2 rev7 구현

1. **`physics.lua` 분리:** 물리 기본값(γ, Δcos, 마찰, C_d, airSurface, vMax 1.5, vShed 3.0, 손실, coalesceK, maxSubsteps 4, gatherCells 1.95),
   입력 조립(`P.inputs`), 힘·속도(`P.forces`, `P.speed`), 임계 반지름(`P.criticalRadius`), substep 선택, 진단(`P.diagnose`). 셰이더의 0.072 상수 → `gR2SurfaceTension`.
2. **삭제 대신 속도 제한:** 한 step 이동을 gather 창(1.95셀)으로 자른다. 실제로 떨어져 나가는 것은 `vShed`(3 m/s)를 넘는 방울만. 흔적 손실은 실제 이동 거리로 계산.
3. **자동 substep:** r 2 mm 방울의 예상 속도로 필요한 substep을 계산(사용자 최소값 이상, 최대 4). UI에 한 step 한계 속도를 표시.
4. **Debug 4 물리 보기:** 선명한 원판, 파랑 = 고정, 초록 → 빨강 = 속도(0 → vMax), 마지막 step 진행 방향 쪽 절반이 밝다.
5. **물리 시험 도구:** `Freeze rain`(탄생·haze 정지), `Physics test: drop ladder` 버튼 = 6셀 간격 방울, 반지름이 왼쪽 0.3 mm → 오른쪽 2.2 mm(8단).
   현재 중력·차 가속·공기에서 어느 크기부터, 어느 방향으로 움직이는지 직접 보인다.
6. **물리 패널:** 입력 분해, 임계 반지름(중력 coat/glass, 공기 포함), r 0.5/1/2 mm 속도, substep과 한계 속도.
7. **(광학) 꽃잎 엽 수정:** 디포커스 때 한 방울 안에서도 광선마다 꺾이는 각도가 다르다. rev5는 방울당 평균 기울기 하나만 써서 분산이 0
   → 멀리 떨어진 한 점을 선명하게 샘플(꽃잎). 선형 렌즈 근사로 방울 내부 분산 kl²·(ext²+lat²)/12를 더해 굴절 상 블러에 반영한다.

### 14.3 rev7 확인 순서

1. `check_rainfx2_shaders.py` → 8개(cells, claim, merge, seed, field, source, visor, visor_depth) OK.
2. 물리 패널 숫자: 정지 상태에서 `wind`와 `sim windSpeedKmh`가 Pure Planner 값과 맞는지.
3. 정지 + `drop ladder` + Debug 4: 오른쪽 큰 방울(≈1.1 mm 이상)부터 아래로 미끄러지는지, 바람 쪽으로 기우는지. 패널의 임계 반지름과 비교.
4. 주행(100/200 km/h) + ladder: 작은 방울까지 바람 방향으로 흐르고, 사라지지 않고 경로를 남기는지.
5. Debug 0, aperture 1.2: 꽃잎 엽이 사라지고 부드러운 원판이 되는지.
6. 비용: substep이 자동으로 4까지 오르면 sim 비용이 늘어난다(패스 4개 × substep).

## 15. rev7 게임 결과와 rev8 (2026-10-26)

|항목|rev7 결과|
|---|---|
|FXC|8개 OK, seed에 정수 나머지/나눗셈 경고 4개|
|바람 입력|`windSpeedKmh`와 `|windVelocityKmh|`가 서로 일치. 패널은 API 값(km/h)을 /3.6 해서 m/s로 표시한다: Pure Planner 65.7 km/h일 때 패널 20.5 m/s = API 73.8 km/h. Pure Planner 표시보다 12% 크다(돌풍·고도 보정 추정). 단위 해석은 맞다|
|drop ladder|중앙부터 오른쪽(큰 방울) 띠가 미끄러짐, 오른쪽 끝일수록 빨강(빠름). 분석 임계 1.12 mm(coat, 4번째 띠 1.11 mm부터)와 일치. 바이저 안쪽에서 보므로 좌우가 반대|
|경로|메쉬를 완전히 벗어날 때까지 사라지지 않고 경로를 남김 → rev7 삭제 버그 수정 확인|
|Debug 4 정지(바람 20.5 m/s)|화면 거의 전부 파랑(고정), 큰 방울도 파랑|
|외형|aperture 0.63/1.2 × bevel 1.5/0.29 비교 이미지|
|비용|draw 0.27 ms, **frame preparation 0.57 ms**(rev3 0.16)|

### 15.1 분석

1. **Debug 4가 전부 파랑:** (a) 생존 편향 — 움직일 수 있는 방울은 이미 메쉬를 떠났고, 남은 것은 고정된 방울이다. (b) **영구 함정** — 고정력 잡음이
   셀마다 고정값(해시)이라, 미끄러지던 방울이 잡음이 큰 셀에 닿으면 정지 임계로 다시 판정되어 그 자리에 영원히 머문다(비가 계속 와서
   더 커지기 전까지). 실제로 움직이는 접촉선은 정지 히스테리시스보다 작은 운동 히스테리시스를 받는다(stick-slip).
2. **frame preparation 0.57 ms:** substep 자동 4 × (cells + claim + merge + field). field(1024×256, 5×5)가 가장 비싸고 substep마다 돌았다.
3. **외형:** bevel 1.5(= 거의 모든 방울이 돔)이 반전 렌즈 상과 밝은 하이라이트가 살아 있어 레퍼런스에 가깝다. bevel 0.29는 평평한 윗면 +
   어두운 테두리라 "물웅덩이"처럼 보인다. aperture 1.2가 B의 부드러움에 더 가깝고, 0.63은 선명하지만 CG 느낌이 남는다. 꽃잎 엽은 사라졌다.

### 15.2 rev8 구현

1. **운동 히스테리시스 (`pinKinetic` 0.6):** 지난 step/frame에 움직인 방울은 고정력 × 0.6. 한 번 출발하면 계속 미끄러진다.
   정지 임계(coat) 1.12 mm → 이동 유지 임계 0.87 mm. 패널에 "keeps sliding from" 표시.
2. **프레임 단위 패스:** substep마다 P1 cells만 돈다. claim/merge와 field는 프레임당 1회. 이동 패킹은 프레임 안의 substep 이동을
   누적(범위 ±8셀, 1/62.5셀 해상도)해서 field 흔적과 Debug 4 속도(프레임 dt)가 프레임 전체 이동을 쓴다. field의 dt = 프레임 dt.
   4 substep에서 패스 16 → 7, field 4 → 1.
3. seed 경고 제거(uint 연산).
4. 기본값: `bevelMM` 1.5, `contourAmp` 0.25(저장값이 있으면 그대로).

### 15.3 rev8 확인

1. FXC 8개 경고 없음.
2. 정지 + 비 + Debug 4: 큰 방울이 초록/빨강으로 미끄러지며 줄을 그리고, 파랑은 작은 방울 위주인지.
3. ladder: 중간 띠(0.84–1.11 mm)도 한 번 밀리면 계속 내려가는지.
4. 비용: frame preparation 0.57 ms → 약 0.2 ms 목표.

## 16. rev8 게임 결과와 rev9 — 관찰 가능한 물리 (2026-10-26)

|항목|rev8 결과|
|---|---|
|FXC|8개 OK, 경고 없음|
|Debug 4|초록인 동안 지나가 버려 다른 색을 관찰하지 못함|
|ladder|움직임이 시작되면 짧은 순간에 바이저를 완전히 벗어남. 계속 미끄러지는지, 한 번의 힘으로 가로지르는지 구분 불가. **한 번 움직인 뒤 중간에 멈추는 방울도 있음**|
|비용|frame preparation 0.57 → **0.30 ms**|

### 16.1 영상 분석 (30 fps, 0.1 s 간격 프레임)

- ladder 생성 직후 한 프레임에 거의 모든 방울이 초록, 다음 0.1 s 안에 대부분 사라지고 아래쪽에 몇 개만 남는다.
  → 이동 속도 ≥ 0.5 m/s. 이는 4 substep의 **한 step 한계(≈0.54 m/s)** 와 같다. 바람 20.5 m/s(면을 따라 흐르는 상한)에서 계산 속도는
  r 0.84 mm 0.49, 1.11 mm 0.89, 1.5 mm 1.55, 2.2 mm 3.0 m/s(→ 떨어져 나감)라서, 대부분 한계에 걸려 같은 속도로 움직였다.
  색은 vMax(1.5) 기준이었으므로 0.54/1.5 = 0.36 → 항상 초록. 70 mm를 0.13 s(30 fps 영상 4프레임)에 지나가므로 눈으로 구분할 수 없었다.
- 중간에 멈춤: (1) **흔적 손실 과다** — `trailLoss` 0.02는 r 0.5 mm 방울에서 mm당 1.9%, 바이저를 가로지르면 부피 절반을 잃어
  운동 임계 아래로 줄어 멈춘다. (2) 곡면 바이저에서 바람과 면의 각도가 위치마다 달라 접선 힘이 줄어드는 곳이 있다(실제 현상).
  (3) 운동 히스테리시스 0.6 × 강한 셀 잡음(최대 1.4)이 정지 최소(0.6)보다 크다 — 실제 stick-slip.
- 정지 상태 바람: CSP 바람은 피트·콕핏 차폐를 모른다. 피트 안에서 74 km/h 바람을 그대로 받는 것은 과하다.

### 16.2 rev9 구현

1. **Physics time scale (0.05–1, 저장 안 함):** 물리 dt를 줄여 슬로모션으로 본다. step 길이도 줄어 한계 속도가 올라가므로 슬로모션에서는 속도 제한 없이 실제 속도대로 움직인다.
2. **Debug 4 개선:** 색 기준을 vMax 대신 **solver 한계 속도**로 바꾸고, 한계에 걸린 방울은 **자홍**으로 표시한다. 배경에 흔적 field(회색)를 그려,
   연속된 선 = 미끄러짐, 끊김 = 점프를 구분한다.
3. `trailLoss` 0.02 → 0.005(r 0.5 mm에서 mm당 0.5%).
4. `windK`(Ambient wind reaching the visor, 0–1, 저장): 주변 바람 중 바이저에 닿는 비율. 차 속도에서 오는 공기는 그대로.

### 16.3 rev9 확인

1. 정지 + ladder + time scale 0.1 + Debug 4: 방울이 회색 선을 그리며 연속으로 내려가는지, 자홍(한계)이 얼마나 많은지.
2. 같은 조건에서 wind factor 0 → 중력만: 1.11 mm 이상 띠만 움직이고 속도는 초록~노랑이어야 한다(r 1.5 mm 0.34, 2.2 mm 1.23 m/s, 한계 0.54).
3. time scale 1로 돌아가 자홍이 대부분이면, 4 substep 한계가 실제 속도보다 낮다는 뜻이다 → `maxSubsteps` 상향(비용) 또는 수용 여부 결정.

## 17. rev9 게임 결과와 rev10 (2026-10-26)

|항목|rev9 결과|
|---|---|
|흔적|움직인 방울은 모두 회색 선을 **끊김 없이** 그리며 내려감 → 연속 미끄럼 확인(점프 아님)|
|색|time scale과 관계없이 움직이는 방울은 모두 초록, 자홍 없음|
|바람 0 (중력만)|중간보다 왼쪽(작은 띠)에서도 움직임. 모두 초록. 바이저 안쪽 시점이라 좌우 반대|
|프레임|107 fps|

### 17.1 해석 (중력만, 수직면, coat)

|띠 r (mm)|0.84|1.11|1.39|1.66|1.93|2.20|
|---|---|---|---|---|---|---|
|정지 잡음 1.0 속도 (m/s)|0|0|0.23|0.51|0.84|1.23|
|잡음 0.6 또는 이동 중(×0.6)|0|0.17|0.40|0.68|1.01|1.40|

- 고정력 잡음 0.6–1.4 때문에 정지 임계는 셀마다 0.87–1.33 mm다 → 1.11 mm 띠(중간 바로 아래)도 일부 움직이는 것이 맞다.
- 107 fps에서 자동 substep 4 → 한 step 한계 0.97 m/s. 이를 넘는 것은 2.2 mm 띠(1.2–1.4 m/s)뿐이고, 바이저는 기울어 있어
  접선 중력이 g보다 작다(수직 대비 cos θ) → 한계에 걸리지 않아 자홍이 없는 것이 맞다.
- 초록만 보인 것은 rev9 색 기준이 한계 속도(슬로모션에서는 커진다) 대비 비율이었기 때문이다.

### 17.2 rev10

Debug 4 색을 **절대 속도 구간**으로 바꿨다: 파랑 고정, 초록 < 0.1, 노랑 < 0.3, 주황 < 0.6, 빨강 ≥ 0.6 m/s, 자홍 = step 한계, 회색 = 흔적.
물리 패널에 범례를 표시한다. 위 표대로라면 중력만일 때 1.11 띠 초록~노랑, 1.39 노랑~주황, 1.66 이상 주황~빨강이어야 한다.

### 17.3 다음 확인

1. 중력만 + ladder: 띠별 색이 위 표와 맞는지(기울기 때문에 한 구간 낮을 수 있음).
2. 주행 100 / 200 km/h + ladder(time scale 1): 바람 방향으로 흐르는지, 자홍 비율. 200 km/h에서 대부분 자홍이면 substep 한계를 받아들일지 결정.
3. 물리 단계가 통과되면 다음은 A 레짐(고속 수막 W, 스프레이)과 B의 haze·닦인 경로.

### 17.4 rev10 결과와 물리 단계 결론

|조건|결과|
|---|---|
|중력만 + ladder|가장 오른쪽(2.2 mm) 주황(0.3–0.6 m/s), 가운데 초록(< 0.1), 자홍 없음|
|주행 100 / 200 km/h + ladder|자홍 없음|

- 2.2 mm가 수직면 계산(1.2–1.4 m/s)보다 한두 구간 느리다. 주황(≈0.45 m/s)에 맞추면 접선 중력 ≈ 0.43 g다. ladder 행은 기울고 굽은 윗부분까지
  퍼져 있으므로 평균 기울기를 생각하면 타당하다(가운데 띠가 초록인 것도 같은 비율로 맞다).
- 주행 중에도 한계에 걸리지 않는다: 상대 공기는 대부분 차 진행 방향이고 바이저 정면은 그 방향을 향하므로, 면을 따라 흐르는 성분
  (공기 − n(공기·n))이 작다(정체점 흐름). 레퍼런스 B(고속·중간 비)에서도 방울 대부분이 거의 제자리에 머물며 부드럽게 보인다 → 방향성은 맞다.
- 결론: 미끄럼 연속성, 크기 임계, 중력/공기 방향, 흔적, 삭제 버그 수정, 비용(frame preparation 0.30 ms)이 확인되어 **물리 기초 단계 통과**.
  크기 조정 손잡이: 고속에서 더 흐르게 하려면 `airSurface`(0.35), 느리게 하려면 `friction`(0.06). substep 한계(107 fps에서 0.97 m/s)는 현재 걸리지 않는다.
- 다음 단계: A 레짐(고속 수막 W, 스프레이), B의 haze와 닦인 경로, C의 마른 상태 방울.

## 18. rev11 — A 레짐 수막(W)과 스프레이 (2026-10-26)

### 18.1 레퍼런스 A 분석 (A_sheet 12프레임)

1. **연속 수막의 굴절:** 화면 전체가 큰 규모로 출렁이며 휜다(물결 유리). 흐르는 방향으로 늘어난 줄기(rivulet)가 보인다.
2. **강한 산란·백화:** 배경 대비가 무너지고 청회색으로 하얗게 덮인다. 일부는 공기 중 스프레이(앞차), 일부는 수막의 미세 거칠기.
3. **방울은 수막에 묻혀** 윤곽이 약하다. 아래쪽(콕핏 쪽)에 흐린 방울이 남는다.
4. 원천은 비보다 **앞차 스프레이**가 지배적이다(비만으로는 수막이 생기지 않는다 — 아래 계산).

### 18.2 물리

- 수막 두께 h의 평균 속도(윤활 이론): v = τh/(2μ) + ρ_w g_t h²/(3μ), τ = ½ρ_air C_f |u|u (C_f 0.005, u = 면을 따르는 공기 × airSurface).
  h 0.05 mm, u 21 m/s(차 60 m/s)에서 전단 0.033 m/s, 중력 0.008 m/s. 두꺼워지면 중력 항(h²)이 지배해 빨리 흘러내린다.
- 공급: 방울로 붙지 않은 비(유량 × (1 − stick)) + 스프레이(`sprayFluxMMs` 0.5 mm/s × 스프레이 추정치). 방울 지름 분포로 정한 크기의 스플래시로 확률적으로 떨어진다(3×3 커널).
- 평형(바이저 길이 0.1 m, 유출 + 배수): 비 10 mm/h·60 m/s → ≈0.025 mm(수막 아님), 앞차 20 m 뒤 스프레이 1.1 → ≈0.18 mm(수막).
  NumPy 확인(`docs/prototypes/rainfx2_film_preview.py`): 비만(공급 ×1) 평균 0.0006 mm, ×10 평균 0.15 mm.
- 친수성 코팅 위의 0.02 mm 이하 수막은 방울로 갈라지므로(dewetting) 덮임은 0.02 → 0.08 mm에서 0 → 1.

### 18.3 구현

1. **field B = W** (두께 / `filmMaxMM` 0.5 mm): 역추적 이류(`r2FilmVelocity`, 프레임당 1회), 표면장력 평활(5-tap, `filmDiffuse` 0.6), 확률적 3×3 스플래시 공급,
   배수(`sheetDrain`), 메쉬 밖 유입 0.
2. **`spray.lua`:** 앞쪽 90 m 안의 차마다 exp(−거리/25 m) × exp(−(측방/2.5 m)²) × (속도/50 m/s)², 자차 앞바퀴 0.12 × 자차 속도² 를 더하고 ×노면 물
   (`rainWater`×1.5 + `rainWetness`×0.3, 최대 1). 할당 없음, 차 수만큼 루프 1회. 스프레이는 미세 haze M도 늘린다.
3. **바이저 합성:** 두께 기울기(탭 간격 = max(field texel, 동공 footprint))를 방울 기울기처럼 굴절로 바꾼다(`filmRefract` 12 = 해상되지 않는 파도 기울기 보정).
   덮임 `filmCov`, 블러 `filmMip` 2.5, 백화 `filmVeil` 0.25, 수막 속 방울 윤곽 감쇠 `filmAbsorb` 0.6. 방울 굴절에 수막 굴절을 더한다.
4. **UI:** Film supply gain, Spray gain, Film refraction, Film veil(저장). 패널에 스프레이(노면 물, 차 수, 최근접 거리), 수막 공급, 평형 두께·유속. Debug 5 = 수막 두께.
5. 정지 `Freeze rain`은 수막 공급도 멈춘다.

### 18.4 확인

1. FXC 8개 OK.
2. 비만(혼자 주행, 중간 비): Debug 5가 거의 검정~파랑(수막 없음)이어야 한다.
3. 폭우 + 앞차 뒤 20–40 m(AI 레이스) 또는 Spray gain 상향: 패널 스프레이 > 0.5, Debug 5 청록~흰색, Debug 0에서 물결 굴절·백화.
4. 레퍼런스 A와 비교해 Film refraction / veil 값을 알려주면 기본값에 반영.
5. 비용: field 패스에 이류 5 샘플 + 해시 9개, 바이저에 4 샘플 + 장면 1 샘플 추가.

## 19. rev11 게임 결과와 rev12 — 평가 기준안 (2026-10-26)

|항목|rev11 결과|
|---|---|
|FXC|8개 OK|
|Rain 프로필, intensity 0.503 직접 설정|80 km/h 대부분 파랑(얇은 막 ≥ 0.01 mm), 방울 생성 시 초록 팝인, 270 km/h 이상 노랑 조금|
|Heavy Drizzle(7.5 %)·Rain(12.5 %)|water 100 %에서 스프레이가 화면을 가득 덮음|
|Hurricane|폭우지만 바람이 강하고 water 0 고정 → 수막이 잘 드러나지 않음|
|intensity 60 / wetness 60 / water 96.6 %|앞차 바짝 90 km/h 스프레이 0.20, 155 km/h 0.37, 132 km/h 0.26, 앞차 없이 242 km/h 0.22|
|비용|Events 0.25 ms, frame preparation 0.33 ms|
|사용자 요청|9개 이상 프로필 Debug 0/5 영상(`docs/videos/rev11_GAME_REVIEW/`)을 평가하고 평가 기준안 마련|

분석과 기준안은 **[RAINFX_V2_EVAL.md](RAINFX_V2_EVAL.md)**. 요점:

1. Pure Planner 프로필 12개 판독: intensity 고정, wetness ≈ intensity, **water는 intensity와 독립**(Drizzle 49–98 %, Tornado/Hurricane 0 고정).
2. 모든 영상이 앞차 0대였는데 스프레이 0.15–0.27 → **자차 스프레이 계수 0.12가 수막 공급을 지배**했다. water가 높은 약한 비에서 수막이 강하고
   water 0인 Hurricane에서 약했던 원인이다. Debug 5의 파랑은 0.01 mm 이상의 얇은 막이다(덮임 임계 0.02 mm 아래 → Debug 0에는 안 보임).
3. 앞차 스프레이는 추종 시 0.20–0.37로 반응한다(자차 항 포함). 앞차와의 방향 정합은 T4 구간에서 `nearestM`·`sprayCars`로 확인한다.

rev12 구현:

1. `spraySelf` 0.12 → 0.03(개방형 바퀴의 앞바퀴 물은 낮고 뒤로 튄다).
2. **Metrics:** `metrics.hlsl`이 바이저를 32×8 블록으로 요약(수막 덮임 비율, 방울 면적 덮임, haze 평균, 유효 비율) → `accessData`로 2 Hz 비동기 readback.
   패널에 `Film cover / drop cover / haze` 표시.
3. **Record metrics CSV:** 앱 폴더의 `rainfx2_metrics_<날짜>.csv`에 0.5 s마다 weatherType, intensity, wetness, water, 바람, 속도, 비 유량,
   스프레이, 앞차 수·거리, 수막 공급·평형, 지표, substep을 기록한다.
4. 기준안: 레짐 C/B/A를 비 유량 q_rain과 추종 조건으로 나누고, 지표 목표 범위와 테스트 절차(T1 정지, T2 80 km/h, T3 250 km/h, T4 추종)를 정했다.

## 20. rev12 판정과 rev13 (2026-10-26)

rev12 게임 리뷰: FXC 9개 OK(metrics 정수 나눗셈 경고 2), 12 프로필 × T1–T4 영상·CSV(`docs/videos/rev12_GAME_REVIEW/`), 레퍼런스 튜닝 없음,
프로필 초기값 고정. 판정 표와 요약: [RAINFX_V2_EVAL.md §7](RAINFX_V2_EVAL.md).

rev13 변경:

1. **수막 모자이크 제거:** 바이저가 수막 두께를 4×4 texel **3차 B-spline**으로 재구성하고 기울기를 해석적으로 구한다(16 Load).
   bilinear 기울기는 texel 경계마다 꺾여서, 근접 확대(texel ≈ 20 px)에서 굴절이 정사각 모자이크로 보였다.
2. **방울 잘림 제거:** claim/merge를 프레임 **처음**에 실행한다. merge가 만든 셀 밖 중심을 뒤따르는 P1이 재배치하므로, 바이저의 5×5 탐색 창에
   셀 밖 방울이 보이지 않는다(rev12: 셀 경계를 따라 큰 방울이 잘림).
3. **보정(판정 근거, 기본값 변경):**
   - `airSurface` 0.35 → 0.15: 250 km/h에서 r ≤ 0.3 mm 고정, 0.5 mm 천천히, ≥ 1 mm 흐름/이탈(레퍼런스 B의 고속 정지 방울).
   - 수막 덮임 0.02–0.08 → **0.05–0.15 mm**(소수성 코팅 위 얇은 막은 방울로 갈라짐).
   - `filmRainK` 0.35: 붙지 않은 비 중 수막으로 가는 비율(나머지는 미세 haze). `microK` 6 → 9(A의 haze 부족).
   - `spraySelf` 0.03 → 0.01.
4. metrics 정수 나눗셈 경고 제거(uint).
5. 판정 스크립트 `docs/tools/rainfx2_eval.py`.

확인: FXC 9개 경고 없음 → 같은 절차로 몇 개 프로필(Light Rain, Rain, Heavy Rain, Hurricane; T3·T4) 재녹화 → 스크립트 판정 + 영상에서 모자이크·잘림 확인.

## 21. rev13 판정과 rev14 (2026-10-26)

rev13 게임 리뷰: FXC 9개 경고 없음. 4 프로필 × T3/T4(`docs/videos/rev13_GAME_REVIEW/`). 판정: [RAINFX_V2_EVAL.md §8](RAINFX_V2_EVAL.md).

- 방울 덮임 1.5 % → 4–5 %, C 수막 통과, A haze 충분. 그러나 **비만으로는 B/A 수막이 거의 생기지 않음**(보정 과다).
- 영상 모자이크는 녹화 압축(H.264 2.8 Mbps)의 매크로블록이었다(프레임 원점 정렬 16/32 px 주기). 렌더 결함이 아니다.

rev14 변경(물리 모델로 평형 두께를 계산해 목표 창에 맞춤, 250 km/h·비만):

|파라미터|rev13|rev14|평형 두께 Light / Rain / Heavy / Hurricane (mm)|
|---|---|---|---|
|`filmRainK`|0.35|**0.7**||
|`sheetDrain`|0.5 /s|**0.1 /s** (배수가 아니라 가장자리 유출이 평형을 결정 → 약·강 차이 압축)||
|결과|0.013 / 0.031 / 0.068 / 0.073|→ 0.051 / 0.080 / 0.125 / 0.132|목표: < 0.065 / ≈ 0.08 / ≥ 0.12|

- `microK` 9 → 7(C haze 0.094–0.109가 상한 0.10 경계).
- **스프레이-노면 물:** wet = clamp((water − 0.2)/0.6). 물웅덩이 20 % 미만은 스프레이 없음, 80 %에서 최대(rev13: water×1.5 + wetness×0.3 —
  Light Rain의 water 29 %가 수막을 만드는 스프레이를 냈다).
- 평가 규칙: 추종 A 조건 30 → 40 m(T4 34 m가 B로 분류되던 문제).

예상: Light Rain T3 수막 ≈ 0 %, Rain T3 10–30 %, Heavy Rain/Hurricane T3 > 50 %, Light Rain T4 수막 감소.
확인: 같은 4 프로필 T3/T4 재녹화(30 Mbps 이상) → `rainfx2_eval.py` 판정.

## 22. rev14 판정과 rev15 (2026-10-26)

rev14 게임 리뷰(CQP 22 QHD 60 fps, 공통 시점 PNG, `docs/videos/rev14_GAME_REVIEW/`): FXC 9개 OK. 사용자 확인: 녹화 품질이 모니터상의 표현을 충실히 대변한다(레퍼런스 합치 판정 아님 — 레퍼런스 합치는 미검증).
판정: [RAINFX_V2_EVAL.md §9](RAINFX_V2_EVAL.md) — C·B·A 추종 통과, A 비만 수막 43–48 %(목표 > 50 %), Light Rain T4 수막 40 %(C 초과), B 방울 덮임 미달(미해결).

rev15: `filmRainK` 0.8, 스프레이 노면 물 임계 0.3–0.8. 다음 단계 후보: 레퍼런스 B 방울 덮임 측정으로 목표 재설정, CSP 화면 빗방울 끄기 옵션,
비용 정리(B-spline 포함 draw·sim 측정), legacy RainFX 제거.

## 23. rev16 — 레퍼런스 합치 비교와 산란 베일 (2026-10-26)

우선순위 변경(사용자 합의): rev15 재녹화보다 레퍼런스 합치 비교를 먼저 한다. 비교 방법·결과: [RAINFX_V2_EVAL.md §10](RAINFX_V2_EVAL.md).

변경(visor.hlsl, init.lua):

1. **전면 산란 베일:** `gR2ScatterM/Film/Spray/Max/Mip/Sky/Gain`, `gR2Spray`(Lua 스프레이 추정치). 장면 mip 6.5의 주변광을 하늘·안개색과 섞어
   바이저 전체에 합성: A = a + s − a·s, src = (col·a·(1 − s) + amb·s)/A. 물이 없는 픽셀도 그린다(바이저 마스크 안).
2. 수막 `filmMip` 4.5, `filmAbsorb` 0.8. 방울 `edgeLoss` 0.2, `toneMin` 0.85, `dropVeil` 0.2.
3. 도구: `docs/tools/rainfx2_refcompare.py`(레퍼런스 프레임 폴더 + PNG → 지표 표).

비용: 바이저 픽셀당 장면 샘플 1회 추가(mip 6.5), 산란 계산 몇 ALU. 바이저 전체에 그려지므로 draw 비용이 약간 늘 수 있다.

## 24. rev17 — 대기와 바이저 표면 분리 (2026-10-26)

**원칙(사용자):** 레퍼런스 A의 전역 백화·블러는 앞차 물보라가 채운 대기의 몫이다. 바이저 표면 작용만 분리해서 구현하고, 차량 물보라는
CSP 자체 구현에 맡기며 개입하지 않는다. 표면의 백화(수막·미세 haze 산란)는 남기되 장면 밝기 상승을 표면 효과로 확대 해석하지 않는다.
상세: [RAINFX_V2_EVAL.md §11](RAINFX_V2_EVAL.md).

rev16 결과: FXC 9개 OK. Light Rain 고속 추종 frame preparation 0.39 ms, main pass/transparent 0.36 ms(rev14 근접 위치 0.36 ms와 같은 수준).

rev17 변경:

1. 산란 베일을 표면 전용으로: `scatterSpray` 0.3 → **0**(공중 스프레이 항 제거), `scatterM` 0.9 → 0.35, `scatterFilm` 0.1 → 0.3(수막 위 백화), `scatterMax` 0.5 → 0.35.
2. `Reset look to defaults` 버튼: aperture, refraction, contour, bevel, film refraction/veil, scatter 저장값을 기본으로.
3. metrics CSV에 외형 저장값 7열 추가(apertureMM, refractK, contourAmp, bevelMM, filmRefract, filmVeil, scatterK) → 판정 때 설정 확인.

다음: Reset 후 같은 4 프로필 T3/T4 재녹화 → B 방울 외형(크기·밝기)과 B 전역 비율, A 표면 서명 확인.

## 25. 다음 단계: Water Field 렌즈 이식 계획 (2026-10-26)

rev17 리뷰에서 사용자가 legacy Water Field 물방울 외형을 기준으로 삼기로 했다. 분석·이식 안·예비 비용: [RAINFX_V2_WF_LENS_PLAN.md](RAINFX_V2_WF_LENS_PLAN.md).
요지: v2 시뮬레이션은 유지하고 `visor.hlsl`의 방울 평가를 WF 규칙(포물면 커널 메타볼 합집합, 기울기 ≈ 1.3 at rim, 굴절 0.69, mip 3 + 1.5|s|/1.5,
림 손실 0.75, 글린트 0.45, 하늘 보정, 톤 창 없음)으로 해석적으로 바꾼다. 예상 draw 비용은 rev17과 같거나 낮음.

## 26. 디포커스 분석 (rev18 착수 전, 2026-10-26)

사용자: 디포커스는 거리 기반이어야 하고(레퍼런스: 렌즈 바로 앞 오른쪽은 흐리고 왼쪽은 선명), rev17 aperture는 물 모양을 바꾸고 굴절을 없앤다.
분석·제안: [RAINFX_V2_DEFOCUS_PLAN.md](RAINFX_V2_DEFOCUS_PLAN.md). 요지: rev5의 "footprint 덮임 + 평균 광선"은 모양(각도 의존 겹침 → 프로펠러)과
굴절(반대 기울기 상쇄)을 망가뜨린다. 디포커스는 선명하게 계산한 렌즈 결과 **색**에만 적용해야 한다. CoC는 얇은 렌즈 식(A, zf, z = length(PosC))으로 거리 기반.
제안 rev18 = WF 렌즈 + D-C 해석 근사(추가 샘플 0) + 거리 기반 CoC, 필요 시 근접 구역에만 D-A 확률적 색 수집.

## 27. 사용자 검토: 디포커스 목표와 굴절 소스 (2026-10-26)

- 디포커스 목표는 오프라인 ② 행(방울 색 층을 거리 기반 CoC로 블러). kn5 배치상 왼쪽이 실제로 더 멀어(CSP 클리핑으로 확인) 거리 보정 불필요.
  구현 순서 D-B → D-A → D-C(임시): [RAINFX_V2_DEFOCUS_PLAN.md §6](RAINFX_V2_DEFOCUS_PLAN.md).
- v2 굴절 소스는 `main.smoke` 시점의 실제 프레임 HDR이라 legacy(LDR GeometryShot)용 하늘·톤 보정이 필요 없다. 남는 과제: 화면 밖 샘플(거울 반사 UV),
  HDR 밝기 확인: [RAINFX_V2_WF_LENS_PLAN.md §6](RAINFX_V2_WF_LENS_PLAN.md).

## 28. rev18 — Water Field 렌즈 + 거리 기반 디포커스(D-C) + 오프스크린 실험 (2026-10-26)

구현(`visor.hlsl`, `init.lua`; 계획: [WF 렌즈](RAINFX_V2_WF_LENS_PLAN.md), [디포커스](RAINFX_V2_DEFOCUS_PLAN.md)):

1. **방울 렌즈 = WF 규칙(해석적):** 5×5 후보마다 돔 커널 h = 1 − (d/1.24R)², 메타볼 합집합 U = 1 − Π(1 − h)(점화식으로 ∇U 동시 계산),
   R > 0.5 mm는 시드 로브 1–2개(거리 0.55R, 0.45–0.55R), 프레임 이동 방향으로 늘임 0.35, 최소 그리기 반지름 0.2 mm.
   실루엣 U = 0.35를 px 부호 거리로 AA. 기울기 s = ∇U·R(가장자리 ≈ 1.3), 오프셋 = s·0.69·(H/W, 1), mip = 2 + 1.5|s|/1.5 + 1.5·largeW
   (WF scene mip 3은 전해상도 shot 기준 → 반해상도 소스에서 2). 림 손실 0.75(0.7–1.3), 글린트 0.45·facing⁴.
   **삭제:** CSP bevel 프로파일, 윤곽 사인 노이즈, 동공 평균 광선(rev5), 톤 창(rev16), `dropVeil`(rev16). 하늘·톤 보정 없음.
2. **화면 밖 샘플:** 거울 반사 UV + 넘친 거리만큼 mip 증가.
3. **디포커스 D-C:** z = |월드(PosL) − 카메라|(그리는 시점의 메쉬 행렬·카메라 위치), CoC_mm = A·|zf − z|/zf, CoC_px = CoC_mm / (mm/px).
   실루엣 폭 = max(1.5, CoC_px)(바깥으로 ¼ CoC 이동), 덮임 × (R/(R + CoC/2))², 굴절 상 mip += ½·log2(1 + 0.35·CoC_px·렌즈 축소율).
   기본 A 1.2 mm, zf 0.12 m. 렌즈 모양·굴절 방향은 CoC로 바꾸지 않는다.
4. **UI:** Drop lens refraction(0.69), Drop image blur(scene mip 2), Drop lobes, Defocus aperture, Defocus focus distance, CoC 요약 줄,
   `Reset look to defaults` 갱신. Debug 6 = R 카메라 거리(0–15 cm), G CoC px(0–40), B 방울 덮임.
5. **D-B 실험 버튼:** `Test: draw visor mesh into an offscreen canvas` → 다음 색 패스에서 `ExtraCanvas:update(function() render.mesh(...) end)`로
   메쉬 UV를 512×288 캔버스에 그리고 readback으로 덮인 샘플 수를 센다. 결과 문자열과 미리보기 이미지가 패널에 나온다(D-B 가능/불가 판정).
6. CSV 외형 열: apertureMM, focusM, wfRefraction, wfSceneMip, filmRefract, filmVeil, scatterK.
7. 검사: `check_rainfx2_shaders.py --dxc <dxc>` 옵션 추가(리눅스 DXC ps_6_0로 문법·의미 검사). 9개 패스 DXC OK. 게임 전 FXC 검사는 그대로 필수.

**버그 수정(중요):** `visor.hlsl`의 이동 해제가 rev8 패킹 변경(1/62.5 셀)을 따라가지 않고 1/250을 쓰고 있었다 → **Debug 4 속도가 4배 작게 표시**됐다.
§17의 해석을 바로잡는다: 중력만일 때 2.2 mm 띠의 주황(표시 0.3–0.6 m/s)은 실제 1.2–2.4 m/s로 수직면 계산(1.23–1.4 m/s)과 맞는다(접선 중력 0.43 g 가설은 불필요).
자홍(step 한계 0.97 m/s @107 fps)도 표시가 4배 낮아 보이지 않았던 것이며, 실제로는 가장 큰 띠가 한계에 걸렸을 수 있다 → rev18 Debug 4로 재확인.
이번 수정은 Debug 4 표시와 방울 늘임 방향 크기에만 영향(물리·field는 common.hlsl의 올바른 해제를 사용).

확인 순서:
1. FXC 9개 OK.
2. Debug 6: 화면 오른쪽(렌즈 가까움)이 빨강 약·초록 강(CoC 큼), 왼쪽은 초록이 거의 없어야 한다. 반대면 z 계산(PosL·행렬) 문제.
3. Debug 1: 방울 모양이 aperture/focus를 바꿔도 **형태는 유지**되고 경계만 부드러워지는지(rev17의 프로펠러 소멸).
4. Debug 0: 오른쪽 부드러운 원판, 왼쪽 선명한 반전 렌즈. WF 렌즈가 크롬처럼 보이면 Drop image blur 2 → 3, refraction 0.69 → 0.5.
5. Debug 4: 속도 색 재확인(중력만 ladder), 자홍 여부.
6. 오프스크린 실험 버튼 결과 문자열.
7. 비용: draw(rev17 0.36 ms 기준)와 frame preparation.

## 29. rev19 — rev18 검토 반영: 디포커스 불투명도, D-A, 방울 외형 다양화, 미끄럼 속도 (2026-10-26)

rev18 게임 확인(사용자, `docs/videos/rev18_GAME_REVIEW/`): FXC 9 OK, Debug 6 정상(오른쪽 초록 = 근접, 왼쪽 빨강),
Debug 1 모양 유지 통과, 오프스크린 실험 `render.mesh returned true, covered samples 0 / 9216` → **D-B 불가**,
비용 T4 최대 구간 frame preparation 0.40 ms, transparent 0.35 ms(rev17 0.36). 문제 3가지:

1. **디포커스된 방울이 투명해진다**(aperture 0 vs 0.8): 덮임 × (R/(R + c/2))²가 원인. R 1 mm, CoC 0.6 mm면 59 %만 가린다.
   광학적으로 원판(반지름 R) ⊗ CoC 원판(반지름 rb = c/2)의 중심값은 **min(1, (R/rb)²)** 이다 — 블러보다 큰 방울은 끝까지 불투명하다.
   **수정(D-C):** 덮임 = smoothstep(부호거리/CoC_px + ½) × min(1, (R/rb)²). 경계 폭은 CoC 지름에 중심 정렬(rev18의 ¼ CoC 바깥 이동 제거).
2. **모든 방울이 같은 모양**(균일한 방향, 양옆 반달 음영 — legacy WF는 위치·형태마다 어두운 구역이 다름). 원인 분석:
   - 기울기 크기를 화면 px 기울기 × R_px로 계산 → 바이저가 화면에서 한 축으로 눌린 곳에서 그 축 양끝만 |s| > 0.7 → **양옆 반달**(림 손실이 링이 아니라 좌우만).
   - 이동 늘임이 대칭 타원 + `saturate(이동/r)`이라 미끄러지는 모든 방울이 같은 방향·같은 비율(1.35)로 늘어남.
   - 시드가 16개뿐이고 로브는 R > 0.5 mm만. 스크린샷 조건은 refraction 0.14, lobes 꺼짐(기본값 0.69, 켜짐) — 굴절이 약하면 방울 안 상이 주변과 같아 림 패턴만 남는다.
   **수정:** (a) 기울기 크기 = |∇U|_mm × R(표면 기준, 등방) — 화면 방향만 ∇U의 화면 투영에서 취한다.
   (b) 접촉선 고정 타원: 시드로 1–1.22배, 임의 방향. (c) 이동은 **뒤쪽 절반만** 늘인다(눈물방울: 앞은 둥글고 뒤가 가늘어짐), 비율 = 0.35·saturate(v / vMax).
   (d) 로브 R > 0.35 mm, 1/3은 로브 없음, 거리·크기 시드 변동. (e) WF large-drop warp(방울 크기 0.6배 셀 값 노이즈, 4 px × largeW)로 큰 방울 내부 상을 불규칙하게.
   모양 변환(I − u uᵀ s, 대칭)의 야코비안을 기울기에 적용(수치 미분 대조 상대오차 3.5e-10).
3. **Debug 4 자홍(1× 시간에서 오른쪽 ⅓):** 수정된 표시로 보니 중력만으로 2.2 mm가 1.4 m/s — 모세관수 Ca = μv/γ = 0.019로
   미끄러지는 방울의 pearling(꼬리 분열) 전이 Ca ≈ 0.005–0.01(Podgorski·Flesselles·Limat 2001, Le Grand·Daerr·Limat 2005)보다 크다. 물리적으로 너무 빠르다.
   접촉선 소산 F ≈ (3μ ln(L/a)/θ)·4r·v ≈ (0.1–0.15)·r·v. **수정:** friction 0.06 → 0.15, vMax 1.5 → 0.5 m/s(Ca ≈ 0.007),
   vShed 3.0 → 1.2(셰딩 판정은 상한 전 속도를 쓰므로 같은 힘에서 같은 판정 — 고속 기류 셰딩 불변). 중력만: 1.2 mm 0.09, 1.6 mm 0.25, 2.2 mm 0.5 m/s.
   60 fps·4 substep의 step 한계 0.54 m/s > 0.5 → 자홍이 나오지 않아야 한다(mock: step limit 0.54).

**D-A 구현(기본 켬, D-B 불가 판정에 따른 사용자 순서 D-B → D-A → D-C):** CoC > 1 px인 픽셀만 Vogel 원판 4점(픽셀·프레임 회전)에서
선명한 WF 렌즈를 계산해 premultiplied 평균(= ② 색 층 블러). 25개 상태 Load는 한 번만 하고 후보마다 4개 탭 누적기(P, ∇U, R)를 정적 배열로 갱신,
장면 샘플은 탭당 1개(4개). 탭 오프셋 px → mm는 화면-표면 야코비안(pxU, pxV)으로 변환. 굴절 상 mip의 CoC 항은 ½만 남긴다(나머지는 탭 분산이 담당).
CoC ≤ 1 px(왼쪽)는 기존 1탭 경로. UI `Defocus: D-A colour gather` 끄면 D-C. 노이즈는 TAA/DLSS가 정리한다는 가정 — 정지 화면 비교로 확인.

D-B 판정 기록: preview728에서 `ExtraCanvas:update` 콜백 안 `render.mesh`는 true를 반환하지만 캔버스에 아무것도 그리지 않는다
(2D 캔버스 갱신에는 장면 카메라·깊이 상태가 없음). 방울 층을 별도 타깃에 그리는 경로가 없으므로 D-B는 보류한다.

UI/CSV: `Defocus: D-A colour gather` 체크(Reset에 포함), CSV에 defocusDA·lobes 열 추가. 검사: DXC 9 OK, mock OK.

확인 순서:
1. FXC 9개 OK.
2. **Reset look to defaults** 후(refraction 0.69, lobes 켬) Debug 0: 방울마다 모양·어두운 구역이 다른지, 양옆 반달이 사라졌는지. 크롬처럼 보이면 scene mip 2 → 3.
3. aperture 0 vs 1.2(D-A 켬/끔 각각): 큰 방울이 디포커스에서도 뒤 장면을 가리는지(작은 방울만 희미해져야 정상). D-A 노이즈가 DLSS/TAA 후 보이는지.
4. Debug 4 중력만 1×: 자홍 없음, 큰 방울 주황–빨강(0.3–0.5 m/s), 1.2 mm 근처 초록.
5. 비용: transparent(D-A 켬/끔), frame preparation.

## 30. rev20 — 크래시 방어, 컴파일 시간, 접촉각 림, 기류 흔들림, 로브 제거 (2026-10-27)

1. **크래시 방어(원인 추정, 로그 미확인):** 영상(`rev19_appcrash.mp4`)에서 파란 AI 차량이 카메라를 통과해 카메라가 그 차 안/위에 놓인 직후 화면이 멈춘다.
   그 차의 실내·창 효과가 켜지면 CSP가 **다른 렌더 타깃 크기**의 추가 뷰(미러, 다른 차 윈드스크린 패스)를 그 프레임의 메인 뷰 전에 그릴 수 있다.
   기존 `renderViewKey`는 메인 뷰 추적 전의 뷰를 'untracked'로 통과시켰고, 이때 glass `fallbackSource`(전해상도 HDR + mip)와 RainFX2 `source` 캔버스가
   크기가 바뀔 때마다 dispose/재생성된다 → 한 프레임에 여러 번, 아직 바인딩된 텍스처를 해제할 수 있다. 방어:
   - `realvisor.lua renderViewKey`: untracked 뷰라도 마지막 메인 뷰와 크기가 다르면 건너뜀.
   - `R2:draw`: 확립된 메인 크기에만 그림. 새 크기는 30번 연속 그것만 나올 때 채택(창 크기 변경).
   원인 확정에는 CSP 크래시 리포트(`Documents\Assetto Corsa\logs`의 `custom_shaders_patch.log`, crash 폴더의 덤프/리포트)와
   **RainFX v2를 끈 상태에서 같은 장면 재현 여부**가 필요하다.
2. **컴파일 시간:** rev19는 5×5를 펼치고 그 안에 D-A 4탭 × (본체 + 로브 2) → 커널 본문 수백 개. 5×5를 `[loop]`로, 4탭만 펼침(정적 배열 유지). 로브 제거로 추가 감소.
3. **로브 제거:** 돔 커널 h = 1 − (d/Rk)²는 경계에서 기울기가 0이 아니다(C0). 큰 커널 안쪽에 놓인 로브 경계에서 합집합 기울기가 꺾여 방울 안에 또 하나의 테두리가 생긴다
   (사용자: "다른 방울이 융합되지 않고 따로 그려짐"). 모양 변화는 시드 타원·눈물방울·흔들림이 담당한다.
4. **접촉각 림(전체 테두리 현실성):** 림의 어둠은 가장자리 기울기(전반사·굴절 이탈)에서 나온다. 구면 캡에서 가장자리 기울기 = tan θ.
   WF 포물면은 θ와 무관하게 가장자리 1.3, 반경의 54 %부터 손실 → **모든 방울에 넓은 링**. 실제는:
   - 충돌로 퍼진 뒤 수축해 남은 방울은 **후퇴 접촉각** 근처에 머문다(폴리카보네이트·하드코트 정적 ~75–85°, 후퇴 ~50–60°로 가정 — 측정값 아님).
   - 미끄러지는 방울의 뒤쪽은 더 후퇴(이력), 이미 젖은 표면(수막·미세 haze) 위 방울은 접촉각이 크게 낮아 경계가 표면에 녹는다(레퍼런스 A).
   구현: ρ = |∇U|R/1.3(반경 비율)을 구면 캡 기울기 s = ρ sinθ / √(1 − ρ² sin²θ)로 바꾼다. θ = 55° ± 12°(시드), 뒤쪽 −20°×늘임 비율,
   × (1 − 0.5·saturate(film + 2·haze)). 링 시작: 90° ρ 0.57, 55° ρ 0.70, ≤ 35° 링 없음. UI `Drop contact angle`.
5. **기류 흔들림(사용자 아이디어):** 날아가지 않은 부착 방울이 강한 기류에서 요동. 진폭 = 0.12 × smoothstep(0.1, 0.8, Fa/Fpin), Fa/Fpin = C·r·u²
   (C = 0.25ρC_dπ/(2γΔcos), 표면 접선 공기속도 u = 기류 × airSurface). 공기 방향 축으로 늘었다 줄었다(8 Hz × 0.8–1.2, 1.73배 배음) + 0.3R 흔들림 이동.
   방향은 화면-표면 야코비안과 ddx/ddy(posW)로 바이저 mm 좌표의 공기 방향을 구한다. mm 방울의 실제 고유진동(수십 Hz)은 60 fps에서 보이지 않으므로
   보이는 대역(돌풍·스틱슬립)으로 둔 양식화다. 정지(시뮬 일시정지) 시 멈춤. UI `Drop wobble in airflow`.

검사: DXC 9 OK(전체 2.5 s), mock OK. 확인 순서:
1. FXC 시간과 게임 첫 생성 시간이 rev19보다 크게 줄었는지.
2. 크래시 장면 재현(4회): 크래시가 사라지는지. 남으면 RainFX v2 끈 상태로 같은 장면 + CSP 로그.
3. Debug 0: 링이 방울마다 다른지(작고 둥근 방울 얇은 링, 젖은 곳 링 없음), 로브 이중 테두리 소멸. 접촉각 70–90 / 35–45 비교.
4. 고속 주행(T3/T4): 부착 방울 흔들림이 보이는지, 과한지(0.05–0.2).
5. 비용: transparent(D-A 켬/끔), frame preparation.
