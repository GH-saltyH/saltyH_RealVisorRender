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

## 31. rev21 — R-size 충돌 규칙, 응결·수막 머리 방울, haze 닦임, CSP 경로 규칙, D-A 완화 (2026-10-27)

근거: [RAINFX_V2_DROP_SIZE_RESEARCH.md](RAINFX_V2_DROP_SIZE_RESEARCH.md) §3·§4(사용자 승인). rev20 결과는 EVAL §15.

1. **충돌 파편화(`cells.hlsl` 탄생):** 빗방울마다 K = We^½·Re^¼(We = 13.89·v²·d, Re = 1000·v·d, d mm, v = 상대속도 × 노출 = 법선 성분 근사).
   kr = min(1, 58/K), 해상 비율 fRes = 0.8·kr^0.5, 파편 지름 dRes = d·kr^0.3, 기대 파편 수 n = fRes·(d/dRes)³ → 확률 min(n, 1)로 파편 하나를 탄생
   (한 셀 한 방울; 나머지 질량은 haze/수막 몫). 평균 방울 기준 예: 8 mm/h·정지 K 95 → 파편 0.33 mm(빗방울 0.38),
   50 mm/h·80 km/h K 640 → 0.27 mm, 50 mm/h·250 km/h K 2700 → 0.18 mm(rev20까지 0.5 mm 안팎).
   `weather.lua` stickFrac = 평균 방울의 fRes(수막 공급 몫), UI에 K·해상 비율·파편 지름 표시.
   수막 보정: 고속에서 비해상 비율이 0.59 → 0.88(Heavy Rain T3)로 늘어 rev15 수막 보정을 지키도록 filmRainK 0.8 → 0.54.
   그리기 최소 반지름 minDrawMM 0.2 → 0.12 mm(작은 파편이 0.2 mm로 부풀려지지 않게, 서브픽셀은 커버리지로 흐려짐). stickFast 삭제.
2. **보이는 방울은 모여서 생긴다(같은 패스, 빈 셀만):**
   - haze 응결: M > 0.35에서 확률 0.6·(M − 0.35)/s로 지름 0.3–0.6 mm 방울 → 그 방울이 field 패스에서 haze를 모은다(microCollect).
   - 수막 머리: 두께 > 0.08 mm이고 수막 흐름 방향으로 두께가 줄어드는 앞쪽 경계에서 확률 3/s × 앞쪽 정도 × 경사로 지름 clamp(8h, 0.6–2.4) mm 방울(레퍼런스 A 빨간 원).
   - field: 방울이 쓸고 간 자리의 수막 30 % 수거(W *= 1 − cover·0.3).
3. **haze 닦임:** microCollect 0.9 → 0.95, trace의 haze 표시 0.15 → 0.05(지나간 자리는 깨끗, 미세 잔여만).
4. **CSP 채택(`common.hlsl r2Steer`, r2Predict에서 속도 방향만 회전, 속력 유지):**
   - 지그재그: 표면 고정 값 노이즈(6 mm 특징) n → kick = sign(n)·saturate(2|n| − 0.5), 측면 성분 0.35·kick.
   - 흔적 따라가기: 진행 방향 1.5 mm 앞 좌우 ±1 mm의 trace 차이 × 1.5만큼 젖은 쪽으로 회전(rivulet 형성).
   - 위치만의 함수라 모든 수집 셀에서 동일(질량 보존 유지). `physics.lua` 진단은 크기만 보므로 영향 없음.
5. **D-A + 흔들림 flake 완화:** 탭 반경 rb → 0.75 rb, 탭마다 경계 폭 max(1.5, 0.5·CoC) — 원판⊗원판을 탭 분산과 경계 띠가 나눠 맡아 탭 간 분산이 줄어든다.
   흔들림 기본값 0.12 → 0.08(사용자 0.07–0.09).

새 파라미터(init.lua DEFAULTS): splashK0 58, resA 0.5, resB 0.3, nucM 0.35, nucRate 0.6, headMinMM 0.08, headRate 3, filmCollect 0.3,
meander 0.35, meanderMM 6, trailFollow 1.5. 모두 초기 추정값이며 레퍼런스 방울 크기 분포(mm 히스토그램) 측정으로 맞춘다.

검사: DXC 9 OK, mock OK. 확인 순서:
1. FXC 9개 OK.
2. 정지 Rain / Heavy Rain: 방울이 rev20보다 작고 많은지, 큰 방울이 haze 응결·합체로만 자라는지.
3. T3(250 km/h): 새 방울이 거의 점 수준인지, 수막 커버가 rev15 수준(Heavy Rain > 50 %)인지(CSV filmCover).
4. T4 물보라: 수막 앞쪽 경계에서 머리 방울이 돌출하는지(레퍼런스 A 빨간 원).
5. 흐르는 방울 경로가 지그재그·기존 흔적을 따라가는지, 지나간 자리 haze가 닦이는지.
6. D-A + 흔들림 0.08: flake가 줄었는지.
7. 비용: frame preparation(cells에 field 샘플 추가), transparent.

## 32. rev22 — 충돌 청소(격자 제거), 먼 림 렌즈(한쪽 하이라이트), 수막 붕괴 수정 (2026-10-27)

rev21 결과·레퍼런스 비교: EVAL §16.

1. **격자 배열의 원인:** 한 셀에 한 방울. rev21 파편은 작아서(250 km/h 0.18 mm) 공기력에 고정되고 서로 닿지 않아 합쳐지지도 않는다 → 결국 모든 셀이 하나씩 차서
   1.17 mm 격자가 보인다. **충돌 청소:** 튀는 충돌(K > K0)은 지름 β·D(β ≈ 0.87 Re^⅕, 점성 한계 확산비)의 얇은 판으로 퍼지며 그 위의 작은 방울을
   흩뜨린다. 반지름 < 0.3 mm 방울을 비율 impactRate × 노출 × π(βD/2)² × saturate((K − K0)/K0)로 제거(`cells.hlsl`, 질량은 haze 몫).
   평형 점유율 = 탄생 / (탄생 + 청소): Heavy Rain 250 km/h ≈ 9 %(β 7.3, 판 지름 4.2 mm, 청소 4.6/s/방울), 정지 ≈ 20 %(β 4.4).
   큰 방울(합체로 자란 것)은 영향 없음. 계수 clearK 1, clearMaxMM 0.3.
2. **T3 수막 1 %의 원인:** rev21 수막 수거(W *= 1 − cover·0.3)가 **고정된 방울에도** 매 프레임 적용 → 격자처럼 깔린 방울 아래 수막이 계속 지워짐.
   수정: 이번 프레임에 움직인 방울의 덮임(coverM)만 수막을 수거한다.
3. **먼 림 렌즈(한쪽 하이라이트, 밝은 방울):** 렌즈 편향은 기울기에 선형이 아니라 가장자리에서 급격히 커진다. 중심은 약한 근거리 상(굴절 0.14, 사용자 결정 — 기본값으로 채택),
   가장자리는 WF 강도(0.69)의 **먼 반전 상**을 크게 흐려(mip 5) 섞는다: c = lerp(근거리, 먼 상, 0.7·smoothstep(0.25, 1.0, s)).
   위쪽 림은 아래(어두운 지면)를, 아래쪽 림은 위(하늘)를 본다 → 위쪽 어두운 초승달·아래 밝음(레퍼런스 창 방울), 어두운 콕핏 앞에서는 하늘빛을 모아 밝은 방울(F1 추적 영상).
   먼 상은 크게 흐려 크롬 같은 선명한 반사 상이 생기지 않는다. 대칭 림 손실 0.75 → 0.35(한쪽 음영은 먼 상이 담당). UI `Drop rim lens` (0–1).
4. FXC pow 경고 제거(max 가드).

검사: DXC 9 OK, mock OK. 확인 순서:
1. FXC 9개 OK(경고 없음).
2. Debug 1 정지·직진 258 km/h: 격자 배열이 사라지고 희소·무작위가 되는지, 방울이 생겼다 사라지며 교체되는지.
3. T3 Heavy Rain CSV filmCover가 rev15 수준(> 50 %)으로 돌아오는지.
4. Debug 0: 방울 위쪽 어두운 초승달, 어두운 배경 앞에서 밝은 방울인지. 과하면 Drop rim lens 0.4–0.5.
5. 비용: draw(장면 샘플 탭당 +1), sim.

## 33. rev23 — 단계 1 외형: Look lab + 방향성 환경 림 (2026-10-27)

계획: [RAINFX_V2_DROP_PIPELINE_PLAN.md](RAINFX_V2_DROP_PIPELINE_PLAN.md) 단계 1(사용자 동의, "다른 기능을 차단하고 외형만").

1. **Look lab (UI 체크박스):** 물리·탄생·합체·수막·haze·산란·흔들림·디포커스를 모두 끄고, 기준 영상 크기 분포의 **정적 방울 세트**만 그린다.
   - `seed.hlsl` 모드 1: 셀마다 점유 확률 0.3, 반지름 0.12–2.0 mm를 pdf ∝ r^−1.88(기준 영상 히스토그램: 1.5배 구간마다 ×0.7)로 표본, 위치·시드 무작위.
   - 시뮬레이션 일시정지 중에도 동작. `New drop set` 버튼, 점유율·최대 반지름 슬라이더(바꾸면 새 세트).
   - 셰이더: `gR2LookLab`이 켜지면 CoC 0, 수막·haze·산란·흔들림·젖은 표면 평탄화 0.
2. **방향성 환경 림(rev22 먼 상 대체):** 오프라인 비교(`docs/prototypes/rainfx2_looklab_compare.py` → `docs/rainfx2_looklab_rev23.jpg`)에서
   rev22의 "흐린 먼 화면 상"은 사방 균일한 회색 링이 됐다(먼 상이 어디서나 비슷한 평균색). 기준 영상은 **위쪽 굵은 어두운 초승달, 아래쪽 밝음**.
   가장자리 광선은 화면 밖 먼 곳을 보며, 위쪽 림은 아래(지면·차 실내 = 어두움), 아래쪽 림은 위(하늘)를 본다 →
   env = veil × lerp(0.05, 1, smoothstep(−0.3, 0.3, up)), up = 기울기 방향의 화면 위 성분. c = lerp(근거리 상, env, smoothstep(0.3, 0.9, s)).
   대칭 림 손실 0(초승달은 env가 담당), 글린트 0.10, 접촉각 55 → 75°(굵은 초승달). 굴절 0.14 유지.
3. **조리개 기본 0**(디포커스는 단계 4까지 끔). `Drop rim` 슬라이더(0–1, 기본 1).

오프라인 비교 3안(g/h/i) 중 h(접촉각 75, 지면 0.05, 전이 −0.3–0.3)를 기본으로 채택. 한계: 기준 영상의 초승달은 약간 비스듬하고(위-왼쪽) 끝이 가늘다 —
게임 판정 후 envE0/E1·화면 위 방향 기울임으로 보정.

확인 순서:
1. FXC 9 OK.
2. Look lab 켜고 밝은 하늘 배경(바이저 위쪽)·어두운 콕핏 배경 각각 Debug 0 스크린샷 — 기준 영상 프레임과 비교.
3. `Drop rim` 0.6 / 1.0, `Drop contact angle` 60 / 75 / 85 비교.
4. 측정: `python docs/tools/rainfx2_dropsize_ref.py <png> --crop ...`(밝은 배경 영역)으로 분포가 단조 감소하는지.

## 34. rev24 — 물리 plano-convex 렌즈, 중력 처짐, seed 경고 제거 (2026-10-27)

rev23 판정(사용자): 모든 테두리에 두꺼운 그림자 → 불합격. 방울은 카메라가 아니라 **바이저 표면**에 붙어 있고 표면 방향이 위치마다 다르므로
방울마다 담는 빛의 방향이 달라야 한다. plano-convex 렌즈에 충실할 것. 형태는 힘(보통 중력) 방향으로 두껍고 꼬리는 얇게.
FXC: seed에 pow 경고 3개 + 미초기화 경고 1개.

1. **렌즈(`r2DropLens`):** 눈 광선 V가 평평한 접촉면(바이저와 평행)으로 물에 들어가 곡면 캡으로 나간다.
   캡 법선 nD = normalize(n − s·d_up)(n = 바이저 바깥 법선, s = 캡 기울기 tanθ_local, d_up = 중심 방향 월드 벡터 = G.x·Tu + G.y·Tv).
   Vw = refract(V, −n, 1/1.333), Vo = refract(Vw, −nD, 1.333). 전반사면 차 안쪽(어두움, veil × 0.05).
   Vo의 화면 위치 = 카메라 접평면 투영 차(Vo − V) × fovK — 축 부호는 ddx/ddy(V)로 자동 결정(cameraSide/Up 부호 무관).
   화면 밖·카메라 뒤 방향은 월드 높이로 하늘/지면 환경(veil × lerp(0.12, 1, Vo.y)). Fresnel 감쇠 0.85–1.
   대칭 림 손실·글린트·rev23 방향성 환경 림 삭제. 렌즈 세기 `lensK`(1 = 물리, UI 슬라이더) — 기존 WF 굴절 0.14 슬라이더는 더 이상 방울에 쓰지 않는다.
   오프라인 비교(`docs/prototypes/rainfx2_planoconvex_compare.py` → `docs/rainfx2_planoconvex_rev24.jpg`): 기울어진 창(측면 시야)에서
   방울마다 한쪽 어두운 초승달(전반사·지면)과 밝은 반전 하늘 상 — 기준 영상과 같은 구성. 정면으로 보는 바이저 중앙은 초승달이 약하다(물리적으로 맞음).
2. **중력 처짐:** 고정 방울은 본드 수 ∝ (r/1.5 mm)²에 비례해 중력 반대쪽(위)만 늘어남(sagK 0.25) → 아래는 둥글고 두꺼움, 위는 얇게.
   미끄러지는 방울은 기존 이동 방향 눈물방울이 우선.
3. seed: pow → exp2/log2, 분기별 단일 반환(FXC X3571·X4000 제거 목적).

확인: Look lab에서 Debug 0 — 밝은 하늘(바이저 위쪽·옆 기울어진 부분)과 정면 중앙의 방울 비교. lensK 0.5 / 1.0, contact angle 60 / 75 / 85.

## 35. rev25 — 줄무늬·깜빡임 제거, 거리 따라 두꺼워지는 림, 작은 방울 또렷하게 (2026-10-27)

rev24 판정(`docs/videos/rev24_GAME_REVIEW/`): 위치별 음영 방향 동작 확인. 문제 — (a) 가까울수록 테두리 음영이 두꺼워져 근거리에서 테두리 전체를 덮음,
(b) 가깝거나 측면이 강하거나 겹친 방울에서 줄무늬(모아레)·빠른 깜빡임, (c) 입체감 없는 작은 방울(투명, 굴절 상·하이라이트 없음). seed X4000 경고 1개.

원인과 수정:
1. **줄무늬·깜빡임:** 굴절 조회 위치는 렌즈 가장자리에서 픽셀마다 크게 변하는데(반전·축소 상) mip은 기울기로만 정해 너무 낮았다 → 언더샘플링 모아레,
   DLSS 지터와 만나 깜빡임. 전반사 경계도 계단(0/1)이라 겹친 방울 경계에서 깜빡였다.
   - mip = max(기본, ½·log2(조회 UV의 픽셀당 이동량²) − 1)(반해상도 소스) — 조회 위치의 실제 발자국(ddx/ddy)으로 결정, 상한 기본 + 3.
     이를 위해 `r2DropLens`의 조기 반환을 없애고(균일 흐름), 호출부 `[branch]` 제거.
   - 전반사는 굴절 판별식 k로 부드러운 띠(smoothstep(0.06, −0.06, k)).
2. **거리 따라 두꺼운 림:** 거리 자체가 아니라 반경 대비 고정 비율이 화면에서 커 보이는 것. 구면 캡에서 전반사 시작 r/R = sin 48.6° / sin θ —
   θ 75°면 바깥 22 %(면적 39 %)가 어두움, 근거리 큰 방울에서 테두리를 지배. 기준 영상의 얇은 림에 맞춰 **θ 55°(±10)** → 바깥 8 %.
   전반사 색도 검정(0.05) 대신 차 안쪽의 흐린 장면 × 0.35(광선이 접촉면을 지나 안쪽을 봄).
3. **작은 방울:** 경계 AA 띠를 반경의 35 %로 제한(최소 0.75 px) — 1.5 px 띠가 작은 방울을 반투명 원판으로 만들던 문제. 발자국 mip 상한(기본 + 3)으로 작은 방울도 자기 굴절 상을 유지.
4. seed: 분기 전체를 단일 결과 변수 + 단일 반환으로 재구성.

확인: Look lab Debug 0 — rev24와 같은 근거리·측면·겹침 장면(`rev24_artifacts.mp4` 위치)에서 줄무늬·깜빡임, 근거리 림 두께, 작은 방울의 상.
접촉각 45 / 55 / 65 비교.

## 36. rev26 — 측면 시야 줄무늬(zebra), 반투명 방울, 삼각형 경계 (2026-10-27)

rev25 판정(`docs/videos/rev25_GAME_REVIEW/`): FXC 9 OK(경고 없음). 아티팩트 양상은 바뀌었으나 남음 — 측면으로 보이는 큰 방울에 **얼룩말 줄무늬**,
측면 표면의 많은 방울이 반투명해 표현력이 없음. legacy WF 비교 영상(`rev25_PrevRainFX_comparison.mp4`): legacy는 측면에서도 윤곽·어두운 테두리가 분명.

원인과 수정:
1. **줄무늬:** 측면(스치는) 시야에서 나간 광선이 카메라 시선과 거의 직각 → 투영 1/dot(Vo, look)이 화면 폭의 몇 배 오프셋을 만들고,
   r2Mirror가 그 값을 앞뒤로 접어 픽셀마다 화면 위치가 크게 튐 → 줄무늬. 수정: dot(Vo, look) < 0.45 또는 오프셋 > 0.8 화면 높이면 환경색으로 전환,
   오프셋 길이 상한 1.2.
2. **반투명:** 출구 Fresnel을 상수(0.85–1)로 근사해 임계각 근처의 어두워짐이 없었다. 물→공기 Schlick(공기 쪽 cos, R0 0.02) 반사율로 안쪽 상과 섞음 —
   반사율이 임계각에서 1로 올라가 테두리가 **점진적으로** 전반사 띠로 이어진다(입체감, 측면 방울의 윤곽).
3. **삼각형 경계:** 바이저 법선을 cross(ddx, ddy)(삼각형마다 평평)에서 보간된 정점 법선 NormalW로 교체 — 큰 방울이 삼각형 경계를 넘을 때의 단차 제거.

확인: Look lab Debug 0, rev25 artifacts 영상 위치(측면·근거리)에서 줄무늬 소멸, 측면 방울 윤곽, 정면 방울이 과하게 어두워지지 않는지.

## 37. rev27 — 상과 림 분리, mip 상한 제거, 작은 방울 최소 림, 진단 Debug 7 (2026-10-27)

rev26 판정: 줄무늬 여전, 정면 근접 방울은 그림자가 지배, 측면 방울 흐림, 작은 방울은 거의 반투명.

분석(오프라인, 정면 단일 방울 수치): 물리 출구 Fresnel·전반사만으로는 θ 46–55°에서 어두운 띠가 반경 바깥 10–15 %뿐이다.
따라서 근접 정면 방울의 두꺼운 어두운 링은 Fresnel이 아니라 **렌즈가 보는 상** 쪽에서 온다 — 물리 세기(1.0)의 반전·축소 상은 화면의 넓은 영역
(헬멧 이마·콕핏의 어두운 픽셀 포함)을 담고, 작은 방울은 그 넓은 영역의 평균색(배경과 같은 색)이 되어 반투명해 보인다. 줄무늬는 rev25의 mip 상한(기본 + 3)이
큰·근접 방울의 축소 상을 언더샘플링한 것.

수정:
1. **상과 림 분리:** 상(굴절 방향)은 `lensK`로 줄인 방향(기본 0.35 — 사용자: 약한 굴절이 자연스럽고 강하면 크롬), 림(Fresnel·전반사)은 항상 **물리 출구**로 계산.
2. **최소 림 폭:** 림 계산용 반경을 재매핑해 어두운 띠가 최소 1.2 px(rimMinPx, 최대 반경 45 %) — 작은 방울도 윤곽 유지, 큰 방울은 물리 띠(12 %) 그대로.
3. **mip 상한 제거:** 발자국 mip 상한 9(사실상 무제한).
4. **진단 Debug 7:** 방울만 표시, R = 림(Fresnel·전반사), G = 환경색 전환, B = mip/9. 남는 문제의 원인 항을 화면에서 바로 구분.
5. **굴절 소스 하우징 거리 슬라이더**(기본 0.20 m): 렌즈 상에 헬멧 이마 등 어두운 근거리가 들어오면 올려 본다(Debug 3에서 확인).

주의: 저장된 lensK(1.0)가 남아 있으면 `Reset look to defaults`로 0.35를 적용해야 한다.
확인: Debug 0/7로 rev26과 같은 장면 — 줄무늬, 정면 근접 링, 측면·작은 방울 윤곽. lensK 0.2 / 0.35 / 0.6.

## 38. rev28 — CSP 윈드스크린 방울 셰이딩 이식 (2026-10-27)

rev27 판정: 줄무늬 존재, 측면 작은 방울 반투명 그대로. 사용자 제안: CSP 방울의 두께·윤곽 처리 모방.
분석과 적용: [RAINFX_V2_CSP_DROP_SHADING.md](RAINFX_V2_CSP_DROP_SHADING.md). 요약 — 내부는 약한 화면 굴절, 가파른 림은 화면 대신 큐브맵(월드 방향, ×0.7),
반사 cube × (1 − nz)³. Debug 7: R = 림(큐브맵) 비중, G = 화면 밖, B = mip/9.

## 39. rev29 — CSP 윈드스크린 물 완전 이식(물 지도 + finalize 법선 + 셰이딩) (2026-10-27)

상세: [RAINFX_V2_CSP_DROP_SHADING.md](RAINFX_V2_CSP_DROP_SHADING.md) §5. 새 패스 `wmap`(물 지도 ping-pong + mip), 바이저는 CSP 모드에서 셀 렌즈 루프를 건너뛴다.
확인: FXC 10개(wmap 추가), Look lab Debug 0/7, 주행 중 흔적, 비용(RainFX2 sim/draw).

## 40. rev30 — 지속 아티팩트의 원인 후보(E2/E3 후단 광학), 크기·흔적 조정 (2026-10-27)

rev29 판정: Look lab 정지 상태에서 CSP 방울 형태와 유사. 바이저에는 크기 조정 필요. 흔적이 두껍고 느리게 사라져 끈적함.
비용 피크 sim 0.777 ms, draw 0.321 ms. **방울 렌즈 방식을 여러 번 바꾸고 DLSS를 꺼도(업스케일·샤픈·AA 없음) 점·빗살 무늬가 남는다.**

원인 재검토 — 방울 셰이더 밖에서 공통인 단계: 렌즈 방식(rev18 WF, rev24–27 물리, rev28 CSP, rev29 물 지도)과 DLSS에 무관하다면
방울을 그린 **뒤**에 같은 화면을 다시 처리하는 단계가 의심된다. `realvisor.lua visorSceneStack('post')`는 `RAIN_VISOR_LAYER_OPTICS`(기본 true)일 때
**방울이 그려진 프레임을 다시 복사**(`visorOpticsCapture`, 'E2/E3 source (scene + rain)')해서 E2/E3 내부 유리 광학(4k 릴리프 법선 맵 굴절)과
cached optics 합성으로 바이저 전체에 다시 그린다. 배경이 고른 곳에서는 미세 굴절이 보이지 않지만, **방울처럼 대비가 큰 세부에서는 릴리프 법선 맵의 미세 패턴이
점·빗살 무늬로 드러난다** — 무늬가 방울 안에서만 보이고 방식·DLSS와 무관한 관찰과 일치한다. 미확정(게임 A/B 필요).

확인 방법: Real Visor UI의 `E2/E3 inner glass optics (prototype)` 체크를 끄고 같은 장면 비교. 무늬가 사라지면 E2/E3에서 바이저 물 영역의
릴리프 굴절을 줄이거나(물 덮임만큼 E2 세기 감소), 후단 복사본을 쓰지 않도록 조정한다.

조정: 물 지도 방울 크기 배율 `wmScale` 0.5(UI `Water drop size scale`), 흔적 감쇠 0.5 → 2.0/s(UI 최대 6).

## 41. rev31 — CSP 방식 비채택, 렌즈 = legacy WF 규칙 복귀, 아티팩트 후보 2: 깊이 경쟁 (2026-10-27)

사용자 판정(rev30): E2/E3 및 다른 바이저 광학을 모두 꺼도 무늬 지속 → 후단 광학 가설 기각. legacy 물방울에는 무늬가 없으므로 **v2 경로가 원인**.
CSP 방식 비채택: 낮고 완만한 선, 방울 없는 곳에도 미세 표면이 생겨 굴절상이 과함. P0 / v2 이전(legacy WF) 표현이 레퍼런스에 더 가깝다.

1. **렌즈 모드 0 = legacy WF 규칙(기본):** rev18/19 `r2DropLens`와 동일 — 오프셋 = WF 기울기 × `wfRefraction`(사용자 0.14), mip = scene + slope + large,
   림 손실 0.75(0.7–1.3), 글린트 0.45 facing⁴. 작은 방울 AA 띠 제한(rev25)만 유지. 모드 1 = rev28 CSP 셀 셰이딩(비교용), CSP 물 지도 기본 끔.
2. **아티팩트 후보 2 — 깊이 경쟁(z-fighting):** v2 방울 메쉬는 GLASS_RAINFX를 복사해 표면에서 **0.05 mm**(`RAIN_DYNAMIC_SURFACE_TEST_OFFSET_M`)만 띄운 것이고
   색 패스를 `DepthMode.ReadOnly`(깊이 테스트)로 그렸다. 같은 표면에 깊이를 쓴 것이 있으면 0.05 mm 차이는 깊이 정밀도 이하라 화소마다 통과/탈락이 갈려
   **점·빗살 무늬**가 되고, 비스듬한 시야·근거리에서 심해진다. 렌즈 방식·DLSS와 무관하고 방울(v2가 그리는 곳)에만 보이는 관찰과 일치. legacy 경로는 이 메쉬·깊이 설정을 쓰지 않는다.
   수정: 색 패스 깊이 테스트 끔(`DepthMode.Off`, 바이저는 카메라에 가장 가까운 면이고 마스크로 영역 제한). UI `Artifact test: depth-test the drop colour pass`로 A/B.
   깊이 전용 패스(`visor_depth`)는 그대로.

## 42. rev32 — 경계면 재설계(2구역 WF 렌즈), 작은 방울 반투명, 미세 미분, 단일 반환 (2026-10-27)

rev31 판정: WF에서 아티팩트 노출이 여러 위치·거리에서 크게 줄었으나 **테두리 그늘 구역**에 남음. FXC X4000(r2DropLens 미초기화 가능) 1건.
반투명 작은 방울은 치명적 — 반드시 해결. 깊이 테스트 A/B는 무관하며 켜야 헬멧 하우징이 물을 가린다(기본 켬으로 복귀).
총평: v2 방울은 렌즈 굴절은 우수하지만 **모든 테두리에 일관되게 그린 듯한 그늘·하이라이트**가 부자연스럽다. legacy는 방울마다 경계가 다르다.

판단 근거(레퍼런스 비스듬한 창 영상·legacy 이미지·광학):
- 실제 방울의 테두리 밝기는 "고정 손실"이 아니라 **테두리가 강하게 꺾어 보는 먼 곳의 밝기**(하늘·지면·차체)다. 그래서 위치·방향·배경마다 다르다.
- legacy WF는 방울 전체에 강한 굴절(0.69)을 써서 테두리가 먼 반전 상을 담았다 → 방울마다 다른 경계. v2는 사용자 결정으로 약한 굴절(0.14)을 써서
  테두리에 담기는 상이 바로 옆 배경과 같고, 남는 것은 고정 손실 0.75뿐 → 모든 방울에 같은 그늘.
- 작은 방울도 같은 이유로 내부 상 = 배경 → 반투명 얼룩.

수정:
1. **2구역 WF 렌즈:** 굴절 = lerp(사용자 값 0.14, legacy 0.69(`wfRimRefraction`), rimK), rimK = max(smoothstep(0.45, 1.15, WF 기울기), 작은 방울 가중).
   내부는 자연스러운 약한 굴절, 테두리는 legacy처럼 먼 반전 상(+ mip `rimMip` 1)과 legacy 손실 → 경계가 배경에 따라 방울마다 달라진다.
2. **작은 방울:** 반경 6 px 이하 전부 legacy 세기, 16 px까지 전이(`smallFullPx`/`smallEndPx`). 손실 띠 최소 `rimMinPx` px.
3. **미세 미분(ddx_fine/ddy_fine):** 화면↔표면 야코비안·월드 위치·시선의 미분을 fine으로. coarse 미분은 2×2 쿼드마다 일정해서
   가파른 테두리 띠에서 부호 거리·기울기 방향이 쿼드 단위로 계단 → 2 px 체커·빗살(모든 렌즈 방식, DLSS 무관)과 일치하는 후보.
4. r2DropLens 단일 반환(FXC X4000 제거 목적). UI `Drop rim / small-drop refraction` 슬라이더.

## 43. rev33 — 큰 방울이 검게 되던 버그, 대칭 림 손실 제거, 큰 방울 림 무늬 (2026-10-27)

rev32 판정(하늘 시야): 큰 방울일수록 검고, 테두리가 원 전체를 감쌈. 큰 방울 테두리에 무늬. 사용자: 테두리도 각자의 방향을 담으므로 검은 테두리가 생길 수 없다.

1. **버그(rev32 내 실수):** 작은 방울 최소 림 폭을 위해 손실을 smoothstep(0.7, 1.3, max(slW, 1.3 − 1.3·rimMinPx/Rpx))로 계산했다.
   큰 방울(Rpx 50)에서 두 번째 항이 ≈ 1.26이라 **방울 전체에 손실 0.75** → 큰 방울일수록 검음. Debug 7 사진의 빨강·자홍 중심과 일치. 항 제거.
2. **대칭 림 손실 기본 0**(사용자 원칙). 테두리 색은 legacy 세기 굴절(0.69)이 실제로 보는 방향의 상에서 온다. UI `Drop symmetric rim loss`로 비교 가능.
3. **큰 방울 림 무늬:** 0.69 굴절의 강하게 축소된 상을 고정 mip으로 읽어 언더샘플링 → 조회 uv의 픽셀당 이동(ddx_fine) 발자국 mip을 하한으로.
   또한 큰 방울 내부 왜곡 노이즈의 frac(sin(x)·43758) 해시가 큰 좌표(≈1e5)에서 GPU 정밀도를 잃어 픽셀 단위 무늬 → 정수 해시로 교체.
4. **Debug 8:** 방울 덮임만 흑백 표시 — 남는 무늬가 윤곽(덮임) 자체에 있는지 렌즈 색에 있는지 구분.

## 44. rev33 검토 — 방울별 표면 기반 투영 여부, 두 굴절 파라미터의 실제 적용 범위 (2026-10-27)

rev33 판정: FXC 10 OK, 하늘 기준 검지 않음, 테두리가 방향에 따라 다름. 사용자 질문: (1) 방울이 각자 표면 기반으로 투영하는가,
(2) `Drop lens refraction`은 일부 방울에만, `Drop rim / small-drop refraction`은 전체에 적용되는데 목표에 맞는가.

1. **표면 기반 투영 아님.** WF 모드(기본)의 오프셋 = 화면 공간 기울기 방향 × WF 기울기 크기(표면 mm 기준, 등방) × 굴절 계수.
   바이저 법선·시선 방향을 쓰지 않는다 — 같은 방울은 바이저가 정면이든 비스듬하든 같은 규칙으로 굴절된다(형태의 원근 축소만 반영).
   rev33에서 "테두리가 방향마다 다르게" 보이는 것은 화면 위치에 따라 0.69 오프셋이 가리키는 배경이 달라서이지, 표면 방향 때문이 아니다.
   (표면·시선을 쓰는 경로는 rev24–27 물리 렌즈였고 현재 모드 1은 CSP 셀 셰이딩.)
2. **두 파라미터의 적용 범위(rev32 설계 결함):** 굴절 = lerp(0.14, 0.69, rimK), rimK = max(smoothstep(0.45, 1.15, WF 기울기), smallK),
   smallK = 1(반경 ≤ 6 px) → 0(≥ 16 px). WF 기울기 0.45는 반경의 약 35 % → **0.14는 반경 16 px 이상 방울의 중심 35 %(면적 약 12 %)에만** 적용되고
   나머지(작은 방울 전체, 큰 방울의 바깥 65 %)는 0.69. 사용자가 0.14로 의도한 "전체적으로 약한 굴절·크롬 방지"와 맞지 않는다.

제안(rev34, 확인 후 구현): **방울별 표면 기반 투영 + 단일 세기**
- 방울 캡 법선 = 바이저 법선(보간 NormalW)을 중심 방향으로 기울임(WF 기울기 → 접촉각 캡), 실제 시선으로 물리 굴절 출구 Vo 계산.
- 화면 내 편향은 Vo − V의 화면 투영 × `lens strength`(모든 방울·모든 구역 동일), 화면 밖으로 크게 꺾이거나 전반사면 **큐브맵을 Vo(또는 반사) 방향으로** 조회(CSP 림 방식, 검정 대신 방향의 색).
  → 테두리 색이 바이저 방향·시선에 따라 방울마다 달라진다. 두 굴절 슬라이더는 `lens strength` 하나 + `rim environment`로 정리.
- 작은 방울 예외 제거(최소 AA 띠만 유지). rev24–27의 줄무늬 원인(1/dot(Vo,look) 폭주 + 거울 접기)은 오프셋 상한 + 큐브맵 전환으로 차단.

## 45. rev34 — WF 렌즈를 방울별 표면 기반 투영으로, UI 정리 (2026-10-27)

사용자 결정: 방울마다 표면 기준으로 장면을 굴절. 접촉각은 40–60°가 정상이며 테두리에서 극적으로 말리며 초승달처럼 꺾여야 함(현재는 반달처럼 상을 가짐).
투영 결과를 보고 테두리 입체감 추가 보정이 필요한지, 방울의 일관된 모양·상 때문인지 평가. 파라미터는 유지하고 UI만 정리. CSP는 남기되 WF를 메인으로.

구현(`visor.hlsl` WF 분기):
- 캡 프로파일: WF 합집합의 반경 비율 ρ = d/R → 구면 캡 기울기 tanφ = ρ sinθ / √(1 − ρ² sin²θ)(가장자리 = tanθ). WF 포물면(기울기가 반경에 선형)과 달리
  안쪽은 거의 평평하고 **가장자리에서만 급히 말린다** → 상이 테두리 근처에서 급격히 꺾이는 초승달.
- 캡 법선 N = normalize(n − tanφ·d_up), n = 보간 바이저 법선, d_up = 중심 방향 월드 벡터. 시선 V(실제 카메라)가 접촉면으로 들어가(1/1.333) 캡으로 나감(1.333).
- 화면 오프셋 = (Vo − V)의 카메라 접평면 투영 × k, k = lerp(내부 굴절, 림·작은 방울 굴절, rimK) / 림 굴절 → 림·작은 방울 = 물리, 내부 = 0.14/0.69 비율.
  rimK = max(smoothstep(0.45, 1.15, tanφ), 작은 방울 가중). 캡 프로파일이라 0.14 영역이 반경의 약 절반으로 넓어짐(rev33의 35 %).
- 화면을 벗어나거나 뒤로 꺾이는 광선 → 환경 큐브맵(Vo 방향, ×0.7), 전반사 → 흐린 실내 × 0.35. 발자국 mip. 글린트는 월드 위를 향한 림.
- Debug 7: R = rimK, G = 환경 전환, B = 전반사(또는 mip/18).

UI: 'Drops: WF lens, surface-based (main)' / 'Defocus' / 'Comparison: CSP methods (not adopted)'(접힘) 순서. 레이블을 역할 기준으로 변경
(예: Interior refraction, Rim + small-drop refraction, Contact angle (rim curl), Hide water behind the helmet housing).

## 46. rev35 — 굴절 파라미터 무효 버그, 측면 시야의 두꺼운 림 (2026-10-27)

rev34 판정: 초승달 말림 관찰, 정면 매우 만족, 측면에서도 카메라·표면 구도에 맞는 위치에 말림. 줄무늬 재발 없음, 반투명 방울 소멸(모든 크기·위치에서 고른 표현).
투영만으로 입체감 충분 → 테두리 보정 추가 불필요. 남은 문제: (a) 두 굴절 파라미터가 모두 적용되지 않는 방울 다수(`rev34_WF_not_affected_by_refraction_params.mp4`),
(b) 측면 시야에서 림 굴절 구역이 실제보다 두꺼움(실제는 얇은 원 테두리), (c) 접촉각은 높을수록 보기 좋고 측면에서 낮을수록 검은 반달.

1. **(a) 버그:** k = lerp(내부, 림, rimK) / 림 → rimK = 1(반경 6 px 이하 작은 방울 전체)이면 k = 1로 **림 슬라이더가 스스로 상쇄**, 내부 슬라이더는 rimK < 1에만.
   영상의 Debug 7에서 대부분의 방울이 R = 1(작은 방울)로 확인. 수정: k = lerp(내부, 림, rimK) / 0.69(legacy WF = 물리). 두 슬라이더 모두 항상 작동.
2. **(b) 측면 두꺼운 림:** 스치는 입사에서는 물 속 각도가 임계각에 가까워, 캡이 조금만 반대쪽으로 기울어도 전반사 → 방울 절반이 어두움.
   실제 캡은 안쪽이 더 평평하고 접촉선에서 가장 가파르다. 사시도(1 − |V·n|)에 따라서만 프로파일을 날카롭게: ρ → ρ^p, p = 1 + (rimSharp − 1)·smoothstep(0.35, 0.85, 1 − |V·n|),
   rimSharp 기본 4(UI `Thin rim in side views`). 정면 시야는 변화 없음.
3. 접촉각 기본 55 → 60°(정상 범위 상단, 사용자 관찰).

## 47. rev36 — "v2 체크 상태에서 legacy가 출력됨" 대응 (2026-10-27)

사용자 보고(rev35): FXC 10 OK, 그러나 v2를 켠 상태에서 legacy RainFX가 보인다. 기기 파일(init.lua, visor.hlsl, realvisor.lua)은 커밋본과 동일 확인.
구조: `R2:enabled()` = store.enabled **and not self.err**. 그리기 오류(`Draw: …`, render.mesh pcall) 또는 `Simulate: …`(realvisor.lua onSceneReady pcall)가
한 번이라도 나면 v2가 꺼지고 `rainfx2Arbitrate`가 legacy를 다시 켠다 — 체크박스는 켜진 채. 기존 UI는 상태 줄 끝에만 오류를 붙여 눈에 띄지 않았다.
rev36: 오류 전문을 빨간 글씨로 표시(`v2 stopped, legacy RainFX shown. Error: …`), `ac.warn` 로그, `Clear the v2 error and retry` 버튼.
원인 확정은 표시된 오류 문구로 한다(정적 검사·mock으로는 재현되지 않음).

## 48. rev37 — rev36에서 드러난 오류 수정 (2026-10-27)

게임 오류 문구: `Shader(658, 41-54) gR2SmallFullPx 선언 없이 사용`. 원인: rev35에서 DEFAULTS 줄 끝에 rimSharp 주석을 붙이며 같은 줄의
`smallFullPx = 6, smallEndPx = 16`이 주석 안으로 들어가 nil → CSP는 nil 값을 셰이더에 선언하지 않는다(FXC 검사 도구는 셰이더 사용 이름을 모두 선언하므로 통과).
수정: 두 값을 별도 항목으로 복구. 재발 방지: mock이 그리기 후 visor.hlsl의 모든 gR2 이름이 값 표에 있는지 검사한다.

## 49. rev38 — `Thin rim in side views`가 효과 없던 원인 (2026-10-27)

rev37 판정: v2 정상, Interior refraction은 큰 방울, Rim+small은 모든 방울에 적용(rev35 수정 확인). 정면 동일. `Thin rim in side views`는 효과 없음, 측면은 여전히 두꺼움.
원인: 스치는 시선은 물 속에서 임계각(48.6°)의 1–2° 안쪽으로 들어온다 → 캡이 반대로 1–2°만 기울어도 전반사. rev35의 ρ^p 날카롭게 하기는
ρ 0.5, p 4.5에서도 기울기 ≈ 2°라 여전히 전반사 → 슬라이더를 움직여도 어두운 영역이 그대로였다.
수정: 측면에서는 캡 기울기를 바깥 띠(반경의 1/rimSharp, 기본 4 → 25 %)에만 둔다. ρ_band = saturate((ρ − (1 − bw))/bw), ρ = lerp(ρ, ρ_band, obl),
obl = smoothstep(0.2, 0.7, 1 − |V·n|). 안쪽은 평평 → 공기에서 들어온 광선은 항상 임계각 미만이므로 **전반사가 정확히 0**. 어두운 띠 ≈ bw. 정면 변화 없음.

## 50. rev39 — 측면 큰 방울의 어두운 렌즈 반쪽, 대칭 림 어둡게 슬라이더 연결 (2026-10-27)

rev38 판정: `Thin rim in side views`에 따라 이미지는 변하지만 필요한 역할(측면 큰 방울의 두꺼운 어두운 영역 제거)은 못함. 정면은 어떤 값에서도 훌륭함.
`Extra symmetric rim darkening`은 효과 없음.

1. **측면 어두운 반쪽의 다른 원인:** '카메라 뒤로 꺾임' 판정이 절대값(look·Vo < 0.45)이었다. 가깝고 넓은 카메라의 화면 가장자리에서는 시선 자체가 look·V ≈ 0.5라
   조금만 바깥으로 꺾여도 환경 큐브맵으로 전환 → 측면 큰 방울의 절반이 큐브맵(어두운 지면·차체)으로 칠해졌다. 상대값(look·Vo / look·V < 0.25)으로 변경.
   화면 밖(오프셋 > 0.7 화면 높이) 전환은 유지.
2. 측면 가중 obl 범위 0.2–0.7 → 0.1–0.5(측면 방울에 띠 축소가 약 40 %만 걸리던 문제).
3. **대칭 림 어둡게:** 캡 기울기 1–2.5 구간에 걸었는데 55–60° 캡의 가장자리 기울기는 1.4–1.7이라 거의 0 → 반경 기준 smoothstep(0.7, 1.0, ρ)(legacy 띠)로 변경.
남으면 측면 장면 Debug 7(R 림, G 환경 전환, B 전반사)로 어느 항인지 확인한다.

## 51. rev39 컨펌 — 방울 굴절·경계면 작업 완료 (2026-10-27)

- 사용자 확인: FXC 10개 OK. 측면 시야의 테두리가 "설명 가능한 수준"으로 좋아져 컨펌했다.
  정면 시야에서는 형태에 따라 다양한 경계면이 보인다.
- 방울의 기본 굴절(§45 표면 기반 WF 렌즈)과 경계면(§49–§50)은 이 상태로 고정한다. 기본값은 init.lua DEFAULTS 그대로다.
  사용자 테스트 값: Interior 0.51–0.56, Rim + small 0.32–0.76, Thin rim 4.
- 다음: 단계 1의 마지막 항목으로 형태 다양성을 다룬다. 조사와 비용은 [RAINFX_V2_DROP_SHAPE_RESEARCH.md](RAINFX_V2_DROP_SHAPE_RESEARCH.md).

## 52. rev40 — 단계 2: 멱법칙 크기 혼합, 정체 구역 난류, 모양 64종(P0), 큰 방울 납작함(P3) (2026-10-27)

사용자 결정(rev39 뒤):
- 형태 다변화 중 갈고리(P1)와 합체 기억(P2)은 단계 3 뒤로 미룬다. trail·휩쓸기와 같은 규칙과 상태가 필요하기 때문이다.
- 단계 2(크기 혼합)를 먼저 완성하고, 비용 0에 가까운 P0·P3을 함께 넣는다. 근거: [RAINFX_V2_DROP_SHAPE_RESEARCH.md](RAINFX_V2_DROP_SHAPE_RESEARCH.md) §4–5.

**1. 크기 법칙** (`cells.hlsl`)
- 충돌 파편 지름을 dRes 하나로 고정하지 않는다. dRes × X로 두고, X는 [fragLo, fragHi] = [0.35, 3.0]에서 pdf ∝ X^−(1+a), a = fragA = 0.88인 절단 멱법칙을 따른다.
  - a = 0.88은 기준 영상의 "1.5배 구간당 개수 ×0.7"(1.5^−0.88 = 0.70)이다.
  - 파편은 원래 빗방울보다 커지지 않는다.
- 표본은 역CDF X = (lo^−a + u(hi^−a − lo^−a))^(−1/a)로 뽑는다. Lua `fragLaw`가 lo^−a, hi^−a, −1/a를 넘긴다.
- 질량은 기댓값으로 보존한다. 파편 확률을 E[X³](`gR2FragM3`, 기본값에서 ≈ 1.97)로 나눈다.
  - 그래서 새 방울 수는 rev39의 약 절반이 되고, 대신 크기가 넓게 퍼진다.
- haze 응결로 생기는 방울도 같은 법칙을 따른다: nucDiamMM(0.4) × X, 최대 1.5 mm. 이전에는 0.3–0.6 균등 분포였다.
- 큰 쪽 꼬리는 합체(현행)와 수막 머리 방울이 계속 만든다.

**2. 정체 구역 난류** (`common.hlsl r2TurbAir`)
- 직진 시 바이저 중앙은 기류가 법선 방향이라 평균 접선 공기 ≈ 0이다. 그래서 작은 방울이 계속 고이고 정렬되어 보였다(rev22 리뷰).
- 접선 돌풍을 공기 벡터에 더한다.
  - 공간: 값 노이즈, 규모 turbMM = 8 mm.
  - 시간: 조각 turbTau = 0.06 s 사이를 보간한다.
  - 크기: turbK(0.5) × airSurface × |상대 공기|.
- 위치와 시간만의 함수라서 5×5 gather의 모든 셀이 같은 값을 계산한다.
- 250 km/h에서 돌풍 최대 ≈ 5.2 m/s이고, 이것만으로 떨어지는 반지름은 r ≈ 0.6–1.4 mm(고정력 불균일)다.
  - 작은 방울은 그대로 머물고(기준 영상과 일치), 큰 방울이 가끔 움직여 길 위 방울을 합친다.
  - Physics 패널에 돌풍 속도와 그 반지름을 표시한다. physics.lua에는 반영하지 않는다(무작위 항).

**3. P0 모양 64종** (`r2PackMove`)
- seed × 2^18 + 이동량(1/31.25 셀, ±8 셀).
- 최대 정수 16 771 572 < 2^24이므로 fp32에서 정확하다.
- visor.hlsl `r2VisorSeed/Move`도 같이 바꿨다. cells·seed의 무작위 시드는 `R2_SEEDS`(64)를 쓴다.

**4. P3 큰 방울 납작함** (`visor.hlsl r2Kernel`)
- 높이를 h = 1 − (1−β)x − βx², x = d²/Rk²로 바꾼다. 기울기는 (1 − β + 2βx) 배다.
- β = flatK(0.5) × ramp(r: flatStartMM 1.0 → flatFullMM 2.2).
- 위가 평평해지고 테가 가팔라져서, 렌즈 내부 굴절이 줄고 림 띠가 좁아진다.
- 윤곽(U = 0.35)은 최대 약 4 % 넓어진다. 같은 부피의 납작한 방울이 실제로 더 넓게 퍼지는 방향과 같다.

**5. 크기 검증 지표** (`sizes.hlsl`, Metrics 켬)
- 8×16 RGBA8 패스로 반지름 구간별 개수를 센다. 구간은 0.08 mm부터 1.5배씩, 마지막은 열린 구간이다.
- 2 Hz 읽기, Metrics를 켰을 때만 돈다.
- UI 표시: 구간별 개수, p50, p90/p50, p99/p50, 구간 비(2–6 구간의 기하 평균). CSV에도 같은 열이 추가된다.
- 목표: 비 ≈ 0.70, p90/p50 ≈ 3–3.5, p99/p50 ≥ 10.
- 기준 영상은 화면 px 지름으로 측정했고, 여기서는 반지름(mm)으로 센다. 같은 거리라면 비율은 같다.

**UI**
- "Drop sizes and stagnation" 구역에 슬라이더 네 개: 크기 법칙 지수, 가장 큰 새 방울 배수, 중앙 돌풍, 큰 방울 평평함.

**비용**
- 난류: 점유된 이웃에서만 r2Predict 1회당 노이즈 4회. 셀 패스 약 +0.01 ms로 추정.
- P3: 방울 평가당 몇 개 명령.
- 크기 패스: Metrics를 켰을 때만 돈다.

**검증**
- DXC 11개 OK.
- mock OK. 시뮬레이션 패스의 gR2 값 누락 검사를 추가했다(rev37 검사를 셀·필드 패스까지 확장).

## 53. rev41 — rev40 리뷰 대응: 정지 표류 버그, 번개 같은 이동, 고속 날림, 작은 방울 밀도, 납작함 해제 (2026-10-28)

**rev40 리뷰** (Heavy Rain 60 %, 정지 / 257 km/h)
- FXC 11개 OK. `sizes`에 X3556 경고 1개(정수 나눗셈)가 있었다.
- 히스토그램
  - 정지: 개수 385, p50 0.26 mm, p90/p50 2.9, p99/p50 5.4, 구간 비 0.74, 덮임 0.4 %.
  - 257 km/h: 개수 ~2 690, p50 0.29 mm, p90/p50 2.1, p99/p50 3.5, 구간 비 0.61, 덮임 2.7 %. 반지름 0.27–0.41 mm에 혹이 있다.
- 사용자 지적
  1. 고속 중앙의 군집과 격자 정렬. 레퍼런스에서는 대부분 날아간다.
  2. P3 납작함: 솥뚜껑처럼 보이고 입체감을 잃었다.
  3. 작은 방울이 훨씬 많아야 하고, 최대 크기는 훨씬 작아야 한다. 이 조건에 가까운 레퍼런스는 `중간보다많은비…1080p`.
  4. 정지 상태에서 방울이 일정한 방향으로 서서히 이동한다(v2 초기부터).
  5. 고속에서 번개 같은 지그재그 경로.
  6. 이동이 전반적으로 너무 빠르다.

**원인과 수정**

1. **정지 표류 (버그, v2 초기부터)**
   - 원인: cells.hlsl이 `saturate(p) * 0.999`로 위치를 기록했다. 서브스텝마다 모든 방울이 셀 안 위치의 0.1 %씩 셀 원점(−u, −v) 쪽으로 끌려갔다(240 스텝/s면 약 4 s에 1 mm).
   - 수정: `min(saturate(p), 0.9995)`로 자르기만 한다.
2. **번개 경로**
   - 오프라인 재현: `docs/tools/rainfx2_airflow_sim.py`, 100–300 km/h × 중앙/중간/측면 × r 0.05–1.5 mm.
   - rev40 값에서는 0.4–1.5 mm 방울이 2 s 동안 0.2–0.7 m를 미끄러졌다. 바이저를 가로지르는 긴 경로다. 원인은 세 가지다.
     - (a) 상한 속도 vMax 0.5 m/s로 오래 이동하고, 떨어져 나가는 문턱 vShed 1.2 m/s가 너무 높다.
     - (b) 경로 굴곡이 sign 킥(±19°가 몇 mm마다 급전환)이고, trail 따라가기가 최대 1.5 → 56°까지 꺾인다.
     - (c) 고정력 불균일이 1.2 mm 셀마다 흰 잡음이라, 문턱 근처 방울이 셀 경계마다 멈췄다 갔다 한다.
   - 수정
     - (a) vMax 0.30, vShed 0.45.
     - (b) 굴곡을 부드러운 노이즈로 바꾸고, 두 항 모두 drive = Fpin/|F|로 줄인다(강하게 밀리는 방울은 직진). 합계 회전은 ≤ 0.5(27°)로 제한한다.
     - (c) 고정력 불균일을 4 mm 규모의 부드러운 표면장으로 바꿨다(`gR2PinScale`).
3. **고속 날림·중앙 군집**
   - 중앙 돌풍 turbK 0.5 → 1.0.
   - 재현 결과(rev41 값)
     - 200–300 km/h: 측면·중간의 r ≥ 0.4 mm와 중앙의 r ≥ 0.4–0.8 mm는 0.03–0.8 s 안에 1–90 mm 이동 후 떨어져 나간다(짧은 trail).
     - r 0.1–0.2 mm는 천천히 기거나(≤ 0.13 m/s) 머문다.
     - 100 km/h: r ≥ 0.8 mm만 천천히 움직인다.
4. **작은 방울 밀도·크기**
   - 고속 rev40에서 보이던 방울은 대부분 haze 응결(0.4 mm × X)에서 왔고, 셀마다 비슷한 크기로 생겨 격자처럼 보였다.
   - 충돌 파편은 0.18 mm(반지름 0.09) × X라서 대부분 최소 반지름 0.08 아래로 사라졌다.
   - 수정
     - 충돌 하나의 파편이 lamella 넓이(여러 셀)에 퍼진다. 셀 탄생률 = λ × min(nFrag, fragMax 12).
     - resA 0.5 → 0.3(250 km/h에서 해상되는 비율 0.11 → 0.25), resB 0.3 → 0.4(파편 0.12 mm).
     - 응결 지름 0.4 → 0.2 mm.
     - 최소 반지름 0.08 → 0.04, 최소 그리기 반지름 0.12 → 0.06, 최대 반지름 2.2 → 1.5.
   - 군집: 탄생률에 약 12 mm 규모로 천천히 흐르는 저주파장(clusterK 0.6, 평균 1)을 곱해, 무리가 생겼다 흩어진다.
   - 히스토그램은 0.04 mm부터 10구간으로 늘렸다.
5. **P3 납작함**: 기본값 0(꺼짐). 슬라이더는 비교용으로 남긴다.

**UI 추가** (크기 구역)
- 충돌당 작은 방울 최대 수.
- 방울 무리.
- 날아가는 속도(vShed).

**검증**
- DXC 11개 OK. `sizes` 정수 나눗셈을 uint로 바꿨다.
- mock OK.

## 54. rev42 — rev41 리뷰: 이동 녹화 분석, "알루미늄" 내부의 원인, 로우 폴리 제안 검증 (2026-10-28)

**rev41 리뷰**
- FXC 11개 OK. 정지 표류 해결을 사용자가 확인했다.
- 고속 히스토그램: p50 0.11 mm, p90/p50 2.9, p99/p50 5.4, 구간 비 0.45. 정지: p50 0.13 mm, 비 0.62.
- 사용자 지적
  - 이동이 여전히 현실을 설명하지 못한다. 녹화: `docs/videos/rev41_GAME_REVIEW/rev41_WF_physics_highspeed.mp4`, 2560×1440 60 fps 11.5 s.
  - 모든 방울의 내부가 알루미늄처럼 평평하다.
  - 제안: 로우 폴리 표면, 디포커스.

### 1. 녹화 분석
- 하늘 구역 40프레임(0.67 s) 최소값 누적: `docs/prototypes/rainfx2_rev41_motion_minstack.png`.
  - 움직이는 방울이 연속 궤적이 아니라 **초승달 복사본의 줄**로 남는다. 멈춤-점프를 반복한다는 뜻이다.
  - 방향은 위·오른쪽(바깥)이다.
- 4프레임 간격 타일: 방울이 한두 타일 사이에 **나타났다 사라진다**.
- 원인
  - (a) **거리 척도.** 바이저는 눈에서 약 5 cm이고 1 mm ≈ 30 px다. 0.3 m/s는 프레임당 약 150 px라서, rev41 vMax 0.30에서 움직이는 방울은 모두 점프나 섬광으로 보인다. 현실에서도 이 거리에서 수 cm/s 이상은 "휙" 지나간다.
  - (b) 돌풍(turbK 1.0, 0.06 s)이 문턱 근처 방울을 간헐적으로 밀어 멈춤-점프를 만든다.
  - (c) 탄생 직후 바로 날아갈 크기의 방울이 태어났다가 한두 프레임 안에 사라진다(깜빡임).
  - (d) 투영된 기류만 쓰면 위·바깥으로 흐르는데, 실제 영상은 아래로 흐른다(§5 사용자 관찰).
- 수정
  - (a) 두 영역으로 나눈다.
    - **날아감:** 공기 항력만으로 shedK(2.0) × 고정력을 넘으면 즉시 제거한다.
    - **기어감:** 준정상 속도를 vMax(0.03 m/s)로 tanh 포화한다.
    - 오프라인(`rainfx2_airflow_sim.py --rev 42`): 200–300 km/h에서 방울은 머물거나 1 mm 안쪽 이동 후 0.01–1 s 안에 날아간다. 100 km/h에서는 1.5 mm만 3 cm/s로 긴다.
  - (b) turbK 0.6, turbTau 0.2 s.
  - (c) 충돌 파편과 응결 방울은 그 자리에서 바로 날아갈 크기면 태어나지 않는다(분무로 간주).
  - (d) airDown 0.5: 표면 평균 공기의 50 %를 바이저의 아래 방향으로 돌린다. 관찰 기반 보정이며 슬라이더로 조정한다.

### 2. "알루미늄" 내부
- 원인: rev36의 측면 얇은 테두리(`rimSharp`, 사용자 값 3.1)가 바깥 1/x 띠만 기울이고 **내부를 완전히 평평하게** 만든다.
- rev39가 비스듬함 판정을 0.1–0.5로 넓히면서, 가깝고 굽은 바이저의 대부분 구역에 이 처리가 걸렸다.
- 평평한 내부는 굴절이 없어 배경을 그대로 보여 준다.
- 오프라인 레이트레이스(`docs/prototypes/rainfx2_facet_lens_compare.py` → `rainfx2_facet_lens_compare.png`)
  - B열(rimSharp 3)이 rev41 화면을 그대로 재현한다.
  - A열(물리 구면 캡)은 아래쪽 장면이 위에 맺히는 **뒤집힌 광각 소형 상**을 보여 준다. 레퍼런스(위 어둡고 아래 밝음)와 같은 방향이다.
- 수정: `rimSharp` 기본 1(끔).
- 측면의 두꺼운 어두운 반쪽은 실제 물리(사입사 전반사)이기도 하다. 다시 문제가 되면 내부를 평평하게 하지 않는 다른 방법(전반사 밝기 등)으로 다룬다.
- **Debug 9 추가.** 렌즈가 보는 방향을 표시한다. 빨강 = 아래를 봄, 초록 = 위를 봄.
  - 물리적으로 맞으면 방울 위쪽이 빨강, 아래쪽이 초록이다(뒤집힘).
  - rev41 화면에서는 방울 아래쪽에 어두운 테두리가 보였다. 이것이 부호 문제인지 큐브맵 방향 문제인지 이 화면으로 판정한다.

### 3. 로우 폴리 제안 검증
- **타당한 부분**
  - 매끈한 물리 캡의 내부 상은 약 10–30배 축소된다. 그래서 바이저 거리와 해상도에서 텍스처 필터(mip)가 상을 뭉개고 "덜 또렷하고 단조로운" 내부가 된다.
  - 면을 나누면 면마다 굴절이 일정해져 장면 조각이 축소 없이 옮겨지므로, 깨진 듯한 높은 대비의 무늬가 생긴다.
  - 레퍼런스 방울의 불규칙한 어두운 조각과 인상이 비슷하다. 실제 원인은 접촉선 고정으로 생긴 비구면 표면, 진동, 영상 저해상도·압축이다.
  - 디포커스를 더하면(D열) 면 경계가 녹아 자연스러워진다.
- **한계**
  - 면 수가 적으면 보석이나 디스코볼 같은 인공 패턴이 된다(C열, 4링 × 8섹터).
  - 물리 캡(A열) 자체가 이미 극적인 뒤집힌 상을 만든다.
- **결론**
  - 기본은 물리 캡으로 복원한다(1).
  - 로우 폴리는 선택 슬라이더로 넣는다: `facetK` 0–1, 링·섹터 수, 방울마다 방향을 회전.
  - 비용: 픽셀당 1회(방울당이 아님), atan2 1회와 수십 명령. 무시할 수준이다.
  - 사용자가 A와 로우 폴리 + 디포커스를 게임에서 비교해 결정한다. 디포커스는 단계 4로 남긴다.

**검증**
- DXC 11개 OK, mock OK.
- 탄생 부피 0(분무) 경우 위치 평균의 0 나눗셈을 막았다.

## 55. rev43 — 한 장의 상을 주는 평볼록 렌즈로 재구성, 다각형 로우 폴리, 이동 평가 (2026-10-28)

**rev42 리뷰**
- FXC 11개 OK.
- Debug 9: 위 빨강, 아래 초록. 뒤집힘 방향이 물리와 같아 **부호는 정상**이다.
- 사용자 지적
  - 방울에 가운데 작은 상과 뒤에 깔린 큰 배경 상이 겹친다. 두 상이 같은 장면이 아니라 경계에서 납득할 수 없다(`docs/videos/rev42_GAME_REVIEW/rev42_2중상과물방울굴곡면표현부재.mp4`). 정면 방울에서 특히 심하다.
  - 경계와 중앙을 따로 표현하지 말고, 평볼록 렌즈 원리에 충실하게 다시 만든다.
  - 로우 폴리는 바깥에서 안쪽으로 뭉툭하고 극적으로 깎인 단순 면이어야 한다(첨부: 방울을 단색 다각형 면으로 재해석한 이미지).
  - 100–300 km/h 녹화: `rev42_sprint_100-300kmh_HeavyRain.*`.

### 1. 이중상의 원인
rev34–42 렌즈는 한 방울 안에 서로 다른 세 출처를 섞었다.
- (a) 화면 표본. 내부 굴절과 림 굴절 두 강도로 확대율이 서로 다르다.
- (b) 전반사 영역의 `inner` = 방울 자리 배경을 mip+3으로 흐린 것. 이것이 **큰 배경 상**이다.
- (c) 화면 밖 방향의 CSP 반사 큐브맵. 차 위치에서 찍은 외부 세계라 헤일로·콕핏이 없고 노출도 다르다.
- 녹화에서 헤일로(어두움) 위 방울은 가운데에 헤일로의 작은 뒤집힌 상, 바깥은 큐브맵의 밝은 하늘을 보인다. 장면이 맞지 않는다.

### 2. 새 렌즈 (`visor.hlsl r2DropLens`, lensMode 0)
- 방울의 모든 점이 하나의 물리 광선이다: 평면 접촉면으로 입사 → 구면 캡(접촉각 θ, n 1.333)으로 출사 → 그 출사 방향이 가리키는 장면(무한원, 헬멧 하우징을 제거한 굴절 원본)을 읽는다.
- 가장자리는 크게 꺾이고 가운데는 넓게 퍼지는 것이 굴절 법칙만으로 나온다.
- 강도 슬라이더는 `Lens strength`(lensPhys) 하나다. 1 = 물리. 내부/림 굴절 쌍, 측면 띠(rimSharp), 소형 방울 구간, 큰 방울 워프·흐림, 큐브맵 환경은 렌즈에서 뺐다. 값은 남아 있지만 쓰이지 않는다.
- 화면 밖 방향: 화면 중심 기준 좌표를 x/(1 + (|x|/0.49)^4)^(1/4)로 **연속 압축**해 화면 가장자리 쪽 같은 장면을 읽는다(두 번째 출처가 없다). 뒤로 꺾인 방향은 그 방향의 가장자리로 보낸다.
- 전반사: 같은 상을 envInterior(0.35)배로 어둡게 한다(차 안에서 되돌아온 빛).
- mip: 최종 좌표의 화면 발자국으로 정한다. 가장자리일수록 축소가 커져 자연스럽게 흐려진다.
- 하늘 반사 하이라이트(glint)는 반사광이라 유지한다.
- Debug 7: R = 반경 비율, G = 압축량, B = 전반사/mip. Debug 9: 방향.
- 오프라인 검증 `docs/prototypes/rainfx2_lens_rev43_compare.png`
  - A열: 물리, 진짜 환경.
  - B열: rev41 띠.
  - E열: rev43 규칙. A와 같은 뒤집힌 한 장의 상이고, 경계가 없다.
  - F열: 로우 폴리.

### 3. 로우 폴리 (다각형)
- rev42 극좌표 면은 호 모양 경계라 사용자 의도와 달랐다.
- rev43
  - 커널 자체가 방울마다 5–8각형이다. 각 변 길이는 ±7 % 불균일하고 넓이는 원과 같다.
  - 변 안에서는 거리를 변의 법선 방향으로 재므로, 기울기 방향이 변마다 일정하고 경계가 곧은 모서리다.
  - 렌즈에서 반경을 평평한 고리(facetRings, 기본 3)로 자른다. 고리 경계는 변과 평행한 직선이고, 각 고리는 안쪽 경사로 평평하다(평평한 윗면 + 뭉툭한 깎임).
- 슬라이더: `Low-poly drop surface`(0 = 매끈), `Flat rings`(2–6).

### 4. 이동 평가 (sprint 녹화 + CSV, 131 → 305 km/h)
- 깜빡임(프레임 간 큰 변화 픽셀 비율)은 2–5 %로 rev41보다 줄었다.
- 최소값 누적(`docs/prototypes/rainfx2_rev42_sprint_minstack.png`)
  - 기는 방울이 거의 같은 간격(프레임당 약 10–15 px)으로 옆(바깥) 방향으로 움직인다.
  - tanh 포화로 **모든 이동 방울이 같은 속도**가 된 "컨베이어" 인상이다. 아래 방향 성분도 약하다.
- 수정
  - 속도를 v = vMax(1 − exp(−vq/vScale)), vMax 0.08, vScale 0.25로 바꿨다. 큰 방울이나 세게 밀리는 방울이 더 빠르다.
  - airDown 0.5 → 0.8.
- CSV(속도 증가 중)
  - 개수 7 000–7 500, 덮임 3.4 → 1.8 %, p50 0.10–0.15 mm.
  - p90/p50 3.0–3.8: 목표 3–3.5 충족.
  - p99/p50 5.7–7.1: 목표 ≥ 10에 못 미친다.
  - 구간 비 0.56–0.59: 목표 0.70보다 가파르다. 큰 쪽이 부족하다.
  - 큰 쪽 꼬리는 단계 3(휩쓸어 합치기)에서 다시 본다.

**검증**: DXC 11개 OK, mock OK.

## 56. rev44 — 정리(로우 폴리·전반사 슬라이더·대칭 림 제거), 결합된 충돌 사건, 물리 모델 문서 (2026-10-28)

**rev43 리뷰**
- FXC 11개 OK. 이중상 해소를 사용자가 확인했다.
- 제거 요청
  - 로우 폴리: 각진 곡면은 원래 방울 해상도와 출력에서 자연스럽게 나왔다.
  - 전반사 밝기 슬라이더: 작동하지 않는다.
  - 대칭 림 어둡게: 전체 외곽에 그려 채택 가능성이 낮다.
- sprint에서 ticking과 순간이동 느낌이 있다. 녹화: `docs/videos/rev43_GAME_REVIEW/`.
- 레퍼런스 이름 규칙 변경과 메모 3개: `docs/videos/ref_OBJECTIVES/rain_profile_map.txt`, `rule_merge.txt`, `rule_trail.txt`.

**제거**
- visor.hlsl: 다각형 커널, 고리 양자화, edgeLoss 줄.
- 전반사는 같은 상 × 0.35로 고정했다. 정면에서는 반경 바깥 ~8 %에만 생겨서 슬라이더 효과가 거의 보이지 않았다.
- init.lua: facet 값과 슬라이더, `Total internal reflection brightness`, `Extra symmetric rim darkening` 슬라이더.

**결합된 충돌 사건** (`cells.hlsl`)
- rev22–43은 작은 방울 정리와 파편 탄생이 셀마다 독립 난수였다. 그래서 원인 없이 사라지고 다른 곳에서 나타났다.
  - rev43 녹화 900 × 300 px 하늘 구역에서 고속 기준 프레임당 2.7개 출현, 2.7–3.0개 소멸.
- 이제 충돌 = (충돌 셀, 서브스텝) 해시로 정해지는 하나의 사건이다.
  - 각 셀이 5 × 5 이웃의 사건을 보고, 충돌점에서 lamella 반경 Rs = 0.5 d·0.87 Re^⅕(최소 0.6 셀) 안이면 반응한다.
  - 튀는 충돌(K > K0)은 그 셀의 작은 방울(r < clearMax)을 쓸어 간다(clearK 확률).
  - 파편은 셀당 min(nFrag, fragMax)/덮인 셀 수의 확률로 받는다. 여러 사건이면 가장 큰 파편 하나다.
- 평균율은 rev41과 같고, 사라짐과 생김이 같은 자리·같은 순간에 일어난다(한 번의 물튐).
- 최소 반지름 미만 파편과 응결 방울은 태어나지 않는다(rev43까지 한 프레임만 존재했다).

**문서**
- 새 문서 [RAINFX_V2_DROP_PHYSICS_MODEL.md](RAINFX_V2_DROP_PHYSICS_MODEL.md).
- 내용: 척도, 현재 구조, ticking 측정과 원인 T1–T6, 레퍼런스 대응표, rule 검토, 계획 A–C.
- rule_trail 7(느릴수록 trail 많음)은 막 두께가 Ca^(2/3)에 비례하는 물리와 반대라서, 속도 의존을 (v/v0)^(2/3)으로 제안했다.

**검증**: DXC 11개 OK, mock OK.

## 57. rev45 — 단계 3 본체: 방울 수명 주기, 물로서의 trail, 휩쓸어 합치기, haze 수거 (2026-10-28)

**사용자 결정**
- rule_trail 7 재검토를 승인했다(빠를수록 막이 두껍고, 문턱 위에서 pearling). 사용자가 rule_trail.txt를 갱신했다.
- 실주행 영상은 흔들림과 저화질 때문에 외형 기준이 아니라 다음의 비교 기준으로 쓴다: 언제 얼마나 생기는가, 주행 방향에 어떤 방향과 속도로 반응하는가, trail 유무, haze 구성.
- 형상, trail 외형, 충돌 임팩트, 방울이 되는 과정의 기준은 `RainFX구현목표_WFShape_TrailShape_ImpactRule_sizeDestribution.mp4`다.
  - 관찰: trail은 머리 방울 뒤에 남는 가늘고 연속된 물줄기다. 폭은 머리 지름의 약 1/4–1/3이고, 가장자리가 어둡게 굴절한다. 몇 초 유지되다 끊겨 점렬이 된다. 작은 방울은 짧은 꼬리만 남긴다.
- 단계 3 제안(DROP_PHYSICS_MODEL §6 B)을 승인했다.

**rev44 sprint 측정** (`rev44_GAME_REVIEW`, 같은 900 × 300 하늘 구역)
- 출현/소멸(프레임당): 2 s 0.7 / 0.5, 6 s 2.8 / 2.2, 10 s 2.1 / 2.2. 보이는 덩어리 172 / 428 / 150.
- 비율로는 rev43 대비 6 s 0.75 → 0.65 %, 10 s 2.2 → 1.4 %. 결합된 충돌만으로는 부분 개선이라, 수명 주기가 필요하다.

**구현**

1. **수명 상태** (상태 텍스처 폭 2배, `S` 1024 × 128 RGBA32F)
   - 오른쪽 절반 L = (나이 s, 남은 비행 시간, 남은 소멸 시간, 비행 방향 rad).
   - cells·merge·seed 패스가 두 절반을 같은 수집으로 쓴다. L은 셀을 차지한 방울(가장 큰 기여자)을 따라간다. 추가 패스와 CPU 호출은 없고, cells GPU 비용은 약 2배다.
   - **탄생:** L = 0. 시각 반지름이 growTime(0.06 s) 동안 0.35 → 1로 자란다.
   - **물튐에 쓸림** (§56 결합된 사건): 같은 사건의 파편이 들어오면 교체, 아니면 fadeTime(0.10 s) 동안 줄어들며 사라진다.
   - **날아감:** 공기 항력 > shedK × 고정력이면 바로 지우지 않는다.
     - 힘 방향으로 flySpeed(0.25 m/s, 수집 창 한도)로 flyTime(0.07 s) 동안 이동한다.
     - visor에서는 그 방향으로 flyStretch(2.5)배 늘어난 꼬리로 그려지고, 크기가 0.55배까지 줄어든다.
     - 지나간 선분에 trail을 남긴다.
   - 비행 중이거나 소멸 중인 방울은 합체하지 않는다(claim에서 제외).
   - 테스트 방울(look lab, ladder)은 나이 10 s(다 자란 상태)다.

2. **trail = 물** (rule_trail 1–11)
   - 깊이(mm) = trailMM(0.08) × (v/trailV0)^(2/3)(≤ 8^(2/3)) × (0.3 + 0.7 × 젖음) × smoothstep(trailRMin, 3 trailRMin, r).
     - 젖음 = saturate(haze M × 1.5 + 수막 h / filmFullMM).
   - 폭 = trailWidthK(0.35) × r.
   - cells: 머리 방울이 깊이 × 폭 × 이동거리만큼 부피를 잃는다(질량 손실). rev7–44의 trailLoss·r² 규칙을 대체한다.
   - field: 같은 깊이를 이동 선분 띠에 수막 W로 쌓는다. 머리 아래 구간은 제외하고, 폭은 최소 0.6 field 텍셀, 한 텍셀 통과분만큼 나눠 쌓는다.
     - 그래서 trail은 물로 그려지고(수막 렌즈·굴절), 공기 전단으로 흐르고, 배수되고, 뒤 방울이 수거한다.
     - "Film supply gain"과 무관하다.
   - trail이 지운 haze 양 × hazeDepthMM(0.004)을 trail에 더한다(rule 11).
   - **pearling/재응결** (rule 10): 빈 셀의 수막 깊이 > pearlMM(0.07)이면 pearlRate(1.5/s) × 초과비로 작은 방울(지름 3h, 0.12–0.6 mm)이 생긴다. 점렬과 잔류 방울이다.

3. **수거** (rule_merge 3): 움직이는 방울이 지나간 haze × hazeDepthMM과 수막 × filmCollect를 2r × 이동거리만큼 부피에 더한다.

4. **휩쓸어 합치기** (rule_merge 1, 6): claim 거리 판정을 점에서 **이동 선분**으로 바꿨다(지난 프레임 이동 = 패킹된 move). 경로 위에서 접촉한 방울과 합친다. 추가 패스는 없다.

**UI** ("Trails and drop life cycle"): trail 물 양, trail 폭, 구슬 맺힘, 비행 시간, 소멸 시간, 성장 시간.

**검증**: DXC 11개 OK, mock OK(셀·필드 패스 값 누락 검사 포함).

### 57.1 rev45a — FXC 오류 수정
- field.hlsl의 지역 변수 이름 `pass`는 FXC(effects 문법)의 예약어라 X3000으로 실패했다. DXC는 통과시킨다. `passK`로 바꿨다.
- `check_rainfx2_shaders.py`에 FXC 예약어(pass, technique, compile, string, shared 등)를 변수 이름으로 쓰는지 검사를 추가했다. Linux DXC 검사에서도 잡힌다.

## 58. rev46 — rev45 리뷰: 두께감 있는 trail, 맑은 trail 물 (2026-10-28)

**rev45 리뷰** (Heavy Rain 60 %, FXC 11개 OK)
- 30 km/h 맞바람: 큰 방울이 아래로 흐르지만 trail에 두께감이 없다. haze만 닦인 자국이다.
- 40 km/h: 흐르는 방울 수가 몇 배로 늘지만 역시 두께감이 없고, 상대풍 150 km/h까지도 같다.
- 바람 0에서 주행하면 200 km/h를 넘을 때부터 접선이 많이 기운 바이저 측면에서만 두께 있는 trail이 생긴다.
- trail이 milky하다. V2 이전 문서에서 같은 문제를 해결한 적이 있다(사용자).

**원인**
- rev45 trail 깊이 = 0.08 mm × (v/0.02 m/s)^(2/3) × (0.3 + 0.7 젖음).
  - 기어가는 방울(0.01–0.03 m/s, 젖음 ~0.3)은 0.026–0.053 mm로, 수막 표시 문턱 0.05 mm 아래였다. 그래서 수막으로 보이지 않고 흔적 T(haze 닦임)만 보였다.
  - 날아가는 방울(0.25 m/s)만 0.16 mm 이상으로 보였다. 그래서 측면에서만 두꺼운 trail이 생겼다.
- milky: 수막 mip 4.5 × 덮임(강한 흐림), veil 0.25, 산란 0.3이 모든 두께에 걸렸다.
  - V2 이전 `RAINFX_TRAIL_REFRACTION.md`(T2, T5)의 결론: 물은 흐리게 하지 않는다. 기본 mip은 낮게, 기울기(곡률)에만 흐림을 더하고, 얇은 물에는 veil을 빼고 굴절된 선명한 상을 쓴다. 가장자리 어두운 선과 하늘 쪽 밝은 선으로 부피감을 준다(T4).

**수정**
- trail 깊이 = trailMM(0.10) × (0.5 + 0.5 (v/v0)^(2/3)) × (0.5 + 0.5 젖음) × smoothstep(rMin, 3 rMin, r) × min(√(r/0.5 mm), 1.6).
  - 미끄러지는 방울은 뒤쪽 접촉선이 남기는 잔류 물줄기를 남기고, 굵기는 머리 크기를 따른다.
  - 예: r 0.8 mm, 0.02 m/s, 젖음 0.3이면 0.08 mm로 보인다.
  - cells의 질량 손실도 같은 식이다.
- 수막 표시 문턱 0.05 / 0.15 → 0.03 / 0.10 mm.
- 수막(trail 물) 셰이딩
  - mip = 덮임 × (0.75 + min(0.6 |기울기|, 2)). rev11–45는 4.5였다.
  - veil과 산란은 두꺼운 수막에만 건다(smoothstep(0.15, 0.4 mm)). 거품 섞인 판만 흐려진다.
  - 가장자리 단서: 기울기가 큰 쪽 × (1 − 0.35), 위를 향한 쪽에 veil 색 밝은 선 0.25 × up⁴.

**검증**: DXC 11개 OK, mock OK.

## 59. rev47 — 물리: 헬멧 공기역학, 목 필터와 방울 관성, trail 물 층 (2026-10-28)

**근거와 사양:** [RAINFX_V2_REV46_REVIEW.md](RAINFX_V2_REV46_REVIEW.md) §1, §3, §4, §7.

**사용자 결정**
- 가속도 소스 = API 차량 가속도(G, 방향 포함) + 바이저 월드 트랜스폼 투영.
- rev47(물리) → rev48(외형) 순서.
- rev48은 A 혼합 지도 방식으로 한다.
- 레거시 마이크로 패턴은 학습하지 않는다. 고정 배경 눈속임 기법이라 작은 방울을 실제 물로 다루는 v2 모델에 맞지 않는다. 그래서 7.4의 "작은 방울 mip 상한" 같은 레거시 유래 항목은 rev48 사양에서 뺀다.

**1. AERO** (`common.hlsl r2DropVelocity`, `physics.lua P.aeroForces/aeroCritical`, `init.lua R2:aeroInputs`)
- 표면 공기를 바꿨다. 이전: 상대풍 접선 × 0.15. 이제: 헬멧 구 유동.
  - u_e = 1.5 kU U · (정체 방향의 접선 성분). 바람을 등진 쪽은 박리(smoothstep)한다.
  - 방울 꼭대기(0.6 r) 유속 = u_e · f(0.6 r/δ). δ = 2.4 √(ν/a), a = 1.5 kU U/R_h(Lua에서 계산).
  - 압력 구배 힘 V ρ u_e · a · cosθ를 공기력에 더한다. 날아감 판정(shedK)에도 포함된다.
- 정체 방향(Lua): 상대풍을 카메라 side 축 기준으로 stagElevDeg만큼 기울인다(정체점이 바이저 중심보다 위 → 바이저 위 흐름은 아래·바깥).
  - 여기에 버피팅 떠돌이(두 사인 합, 진폭 buffetDeg × min(U/250 km/h, 1.5), buffetHz)를 더한다.
- 기본값
  - aeroKU 0.6(콕핏 차폐), helmetR 0.13 m, stagElevDeg 12°, buffetDeg 8°, buffetHz 3.
  - airDown 0.8 → 0(정체점 고도로 대체), turbK 0.6 → 0(떠돌이로 대체).
- 기본값의 쓸림 반지름(공기만, 2 × 고정력, mm)

| 속도 | 경계층 | 2° | 12°(중심) | 20° | 35° | 50° |
|---|---|---|---|---|---|---|
| 50 km/h | 0.95 | - | - | 2.62 | 1.18 | 0.89 |
| 100 km/h | 0.67 | - | 1.74 | 0.82 | 0.52 | 0.41 |
| 200 km/h | 0.47 | 4.76 | 0.57 | 0.36 | 0.24 | 0.20 |
| 300 km/h | 0.39 | 2.94 | 0.35 | 0.23 | 0.16 | 0.13 |

- 그보다 작은 방울도 1–2 × 고정력 사이면 기어간다. Physics 패널에 현재 속도의 2°/20°/50° 값을 표시한다.

**2. JOLT** (`init.lua R2:filterAccel`, `common.hlsl r2Predict`)
- 입력 = 차량 가속도(월드, m/s²) + headAccK × (바이저 위치 2차 차분 − 차량 가속도).
  - 머리 항은 2 g로 제한하고, 1 m 이상 점프하면 초기화한다.
- 축별 2차 저역 필터(neckHz 3, ζ 0.7, 하위 스텝 분할). accelW = 중력 − 필터값.
- 방울 관성: 속도가 목표 속도로 τ = dropTau(0.04 s) 동안 이완한다.
  - 이전 속도 = 패킹된 이동량 / (서브스텝 1이면 지난 프레임 시간, 아니면 (sub−1)·dt).
  - 반대 방향 힘은 0을 거쳐 감속한다. 목표가 0이고 속도 < 2 mm/s면 정지한다.
  - 비행 방울은 제외한다.
- Physics 패널: 원 가속도 / 필터 가속도(g).

**3. T-layer** (`field.hlsl`, `cells.hlsl`, `visor.hlsl`)
- field R = trail 물 깊이 / trailMaxMM(0.5 mm). rev12–46의 haze 닦임 흔적 T를 대체한다(traceHaze 0).
- 고정: 확산과 이류가 없다. 증발 trailEvapMMs(0.025 mm/s)로 0.1 mm는 약 4 s 유지된다. 뒤 방울이 filmCollect로 수거한다.
- 쌓기: 이동 선분 띠, 깊이 r2TrailDepthMM, 최소 폭 0.6 텍셀. 통과 비율로 희석하지 않고 max로 쌓는다. 지운 haze를 더한다.
- rev45–46의 수막 W 가산은 제거했다.
- pearling은 R 기준. 젖음 r2Wet에 R을 포함한다. 흔적 따라가기(r2Steer)는 R(물 깊이)을 따른다.
- visor: 수막 B-spline 16 Load에서 W + R(깊이 환산)을 함께 읽는다. trail이 수막 렌즈로 그려진다(rev46 맑은 셰이딩).

**UI:** "Helmet airflow" 4개(공기 속도 비율, 정체점 고도, 버피팅 진폭·주파수), "Car / head jolts" 3개(목 필터, 머리 가속 비율, 방울 관성), trail 증발. turbK와 airDown 슬라이더는 제거했다.

**검증**: DXC 11개 OK, mock OK, Lua 쓸림 반지름 표 확인.

### 59.1 rev47a — 정지 상태 creep 버그 수정
- 증상: 바람 0, 정지 상태에서 작은 방울이 한 방향으로 약 2 mm/s 기어간다(`rev47_unacceptableMovement.mp4`).
- 원인: 관성의 정지 판정 단위 오류(mm²/s²와 4e-6 비교)와 이동량 패킹 반올림(0.7 단계가 1 단계로 올라감)이 겹쳐 영구 creep이 됐다.
- 수정: 구동력이 없으면 속도 < max(3 mm/s, 1.5 패킹 단계/프레임)에서 정지한다.
- 리뷰 분석과 rev47b 제안: [RAINFX_V2_REV47_REVIEW.md](RAINFX_V2_REV47_REVIEW.md).

## 60. rev47b — runback, 충돌 합류, 원뿔 노출, 헬멧 상단 runoff, 버피팅 완화 (2026-10-28)

**근거:** [RAINFX_V2_REV47_REVIEW.md](RAINFX_V2_REV47_REVIEW.md) §2–§5. 사용자 승인. rev47a FXC 통과.

1. **runback** (`common.hlsl r2DropVelocity / r2Predict`)
   - 공기력 > shedK × 고정력이면 삭제하지 않는다. 미끄러짐 속도 = clamp(runbackK 0.03 × 방울 꼭대기 공기 속도, vMax, runbackMax 0.5 m/s), 방향은 합력이다.
   - 반지름 > liftMM 1.5 mm만 이탈(비행 효과)한다. 나머지는 바이저 가장자리를 넘을 때 사라진다(기존 경계 흡수).
   - 미끄러지는 방울 관성 slideTau 0.1 s. 기는 방울은 dropTau 0.04 s를 유지한다.
   - 휩쓸기 합체, trail, 수거가 그대로 동작한다.
   - 서브스텝: 공기 > 10 m/s면 runbackMax 기준으로 늘린다(최대 4). 프레임당 이동은 수집 창(1.95 셀/서브스텝)으로 제한된다.
   - physics.lua P.speed도 같은 규칙이다.
2. **충돌 합류** (`cells.hlsl`): 튀는 충돌이 작은 방울(r < clearMax)에 닿으면, 그 방울은 impactLoss(0.3)만 잃고 남은 물에 파편 부피가 합쳐진다. 합친 결과가 최소 크기보다 작을 때만 사라진다(fade).
3. "공기가 바로 뜯어낼 크기의 탄생 금지"(rev42)를 제거했다. 파편과 응결 방울 모두 해당한다.
4. **노출** (`r2Exposure`)
   - E = (x + √(x² + s²))/2, x = cos(상대 비, −n), s = sin(rainSpreadDeg 18°).
   - rainExposure 기본 0.5 → 1.0. 저장 키를 `rainExposure`로 새로 만들어 이전 저장값 0.5를 덮어쓰지 않게 했다.
   - UI: 노출(0–1.5), 비 방향 퍼짐.
5. **헬멧 상단 runoff** (`field.hlsl`)
   - 바이저 위쪽 가장자리에서 crownBandMM(3 mm) 안의 텍셀(표면 위쪽으로 한 걸음 가면 바이저를 벗어나는 곳)에 수막을 공급한다. 공급량 = 강우(mm/s) × crownMM(20 mm 집수 길이) / 3 mm.
   - 상대 공기 5–20 m/s에서 사라진다.
   - 수막은 기존 규칙대로 흐르고, 머리 방울을 만들고, 방울에 수거된다.
6. **버피팅** 8°/3 Hz → 4°/1.5 Hz.

**UI 추가:** 미끄럼 관성, runback 속도·최고 속도, 충돌 튐 비율, 상단 runoff, 비 방향 퍼짐.

**검증**: DXC 11개 OK, mock OK.

**판정 기준:** 같은 sprint CSV에서 덮임과 p99/p50이 속도에 따라 줄지 않는가(rev47: 1.56 → 0.29 %). 정지 상태에서 위쪽부터 젖는가. 중심부 쓸림이 직진하는가.

### 60.1 rev47c — 이동 물리량 보정(관찰 기반)
- rev47b 녹화에서 고속 시 보이는 방울의 87 %가 0.1 s 안에 자리를 떠난다(persistence 측정 도구 `docs/tools/rainfx2_drop_persistence.py`). 레퍼런스는 초 단위로 머문다.
- 기본값: aeroKU 0.6 → 0.35, runbackMax 0.5 → 0.06 m/s, runbackK 0.03 → 0.003, slideTau 0.1 → 0.15 s, impactLoss 0.3 → 0.15.
- 상세: [RAINFX_V2_REV47B_REVIEW.md](RAINFX_V2_REV47B_REVIEW.md).

### 60.2 rev47f — 수막 공급의 두 출처 분리
- **확인 결과: trail은 수막이 만들지 않는다.** rev47부터 trail은 field R의 독립 층이고, 움직이는 방울이 잃는 물로만 생긴다. 그려질 때만 수막과 같은 렌즈 경로를 쓴다(visor B-spline이 W + R을 함께 읽음).
- 그래도 `Film supply gain` 0은 trail에 간접적으로 영향을 줬다.
  - (a) trail 깊이의 젖음 계수(haze + 수막 + trail)가 낮아진다.
  - (b) 수막 머리에서 생기는 큰 방울(head drop)이 사라진다.
  - (c) 방울이 수막을 수거해 커지는 경로가 끊긴다.
  - (d) 해상되지 않은 비(고속 76 %)가 버려진다.
- 원인은 rev11부터 filmK가 **비 수막과 스프레이 수막을 함께** 곱한 것이다. 스프레이를 숨기려고 0으로 두면 비 물까지 사라졌다.
- 수정
  - filmRate = 비 수막 × filmK + 스프레이 수막(스프레이 추정 × sprayK × sprayFluxMMs).
  - UI 이름: `Rain film supply gain (keep 1)`, `Spray gain (0 hides spray)`.
- 사용자 계획(trail과 올바른 물리만으로 물보라 효과가 얼마나 나오는지 평가한 뒤 spray film 레짐 제거): 평가할 때는 Spray gain 0, Rain film 1로 둔다. 판정 방법은 [RAINFX_V2_REV47B_REVIEW.md](RAINFX_V2_REV47B_REVIEW.md) §7.

### 60.3 rev47g — 힘 계산에서 카메라 분리 (원칙)
- **원칙(사용자):** 이 프로젝트는 바이저와 따로 움직이는 여러 카메라 위치를 지원한다. 따라서 물리(힘의 방향 성분)는 **바이저 월드 트랜스폼만** 기준으로 계산하고, 카메라는 넣지 않는다. 카메라는 화면 투영(렌즈, 화면 축)에만 쓴다.
- 점검 결과
  - 표면 투영(중력, 가속, 공기): 셀마다 바이저 월드 법선을 쓴다. 이미 준수하고 있다.
  - 가속 입력(rev47 JOLT): 차량 가속도 + 바이저 월드 위치 2차 차분. 이미 준수하고 있다.
  - **정체점 고도와 버피팅 축(rev47 AERO)이 카메라 up/side를 쓰고 있었다 → 바이저 로컬 +Y(월드 변환)와 up × 공기 방향으로 바꿨다.** Physics 패널에 바이저 +Y와 월드 up의 내적을 표시한다(1에 가까워야 한다). 축 보정 프로필로 다르면 알려 달라.
  - 화면 위 방향(screenUp)과 렌즈의 카메라 벡터는 렌더링 전용이라 유지한다.
- **NeckFX 추종:** 바이저 트랜스폼은 NeckFX 목 시뮬레이션이 움직이는 머리(바이저 KN5)를 따른다. 그 2차 차분이 머리의 실제 가속이다. 물리적으로 현실에 충실하므로 유지한다(사용자 확인). 카메라 오프셋만 다른 프리셋은 바이저 트랜스폼이 같으면 물리 결과도 같다.

### 60.4 rev47d sprint (수막 공급 1) 기록
- CSV: 수막 덮임은 165 km/h 7 %에서 295 km/h 62 %로 늘었다. 방울 덮임 3.8 %, 방울로 서 있는 물 깊이 12–21 μm, 머무름 0.08–0.11 s. 수막 평형 두께 0.127 mm.
- 사용자 평가: 이동량 보정 뒤 레퍼런스에 상당히 근접했다. **바이저 정중앙에 물이 고이는 점은 불합격**이다.

### 60.5 rev47h — trail이 사라진 원인 (rev47c 이후)
- 사용자: 이동 속도를 내린 뒤로 처음 보이던 trail이 더 이상 안 보인다(그때도 수막 공급은 0이었다).
- **원인 1 (주원인, 위치 버그):** trail 띠를 이동 선분 a..b에서 머리 반지름만큼 뺀 구간에 쌓았다.
  - rev47c 이후 모든 방울은 프레임당 반지름보다 적게 움직인다. 그러면 구간이 시작점 a 한 점으로 줄고, trail이 **머리 자신의 발자국 아래**에 쌓였다.
  - 다음 프레임에 같은 머리가 수거(coverM × filmCollect)해 지웠다.
  - rev45–46에 보이던 trail은 0.25 m/s 비행 방울이 반지름보다 멀리 움직여서 생긴 것이었다.
- **원인 2 (표시 문턱):** 폭 1텍셀 이하 띠는 B-spline 재구성에서 약 0.6배로 낮아진다. 0.045 mm trail이 수막 표시 문턱 0.03 mm 아래로 떨어졌다.
- 수정
  - trail은 **뒤쪽 접촉선**이 남긴다. 띠 = 이동 선분을 머리 반지름만큼 뒤로 민 구간이다.
  - trail 수거는 움직이는 머리의 **앞쪽 절반**만 한다(뒤쪽은 물을 남기는 쪽). haze·수막 수거는 그대로 둔다.
  - 수막·trail 표시 문턱 0.03/0.10 → 0.02/0.08 mm.
- 확인: Debug 1 파랑(B = trail 물 깊이)이 흐르는 방울 뒤에 줄로 남는지 본다.

### 60.6 rev47i — rev47h 리뷰 수정: 전체 흐림 막, 부채꼴 흐름
- **전체를 흐리게 만드는 막 (의도하지 않음):** rev47h가 수막 표시 문턱을 0.02/0.08 mm로 낮췄다. Rain film supply 1에서 생기는 얇은 비 수막(평형 약 0.1 mm)이 바이저 전체에 보이게 됐다.
  - 수정: 수막 문턱을 0.03/0.10으로 되돌렸다. trail 층(field R)은 자기 문턱 trailMinMM 0.012 / trailFullMM 0.05를 따로 쓴다.
  - visor 덮임 = max(수막(B-spline 두께 − trail), trail(R 깊이)). 렌즈 두께는 둘을 합친 값 그대로다.
- **부채꼴 흐름(아래에서 위로, 좌우로 퍼짐, 아래 성분 없음):** rev47g에서 헬멧 up을 바이저 로컬 +Y로 가정했다. 이 KN5(축 보정 프로필)에서는 +Y가 헬멧 위가 아니다. 그래서 정체점이 바이저 아래쪽으로 기울어 흐름이 아래에서 위로 발산했다.
  - 수정: 바이저 로컬 축 ±X/±Y/±Z 중 월드 up과 가장 잘 맞는 축을 처음 한 번 골라 헬멧 up으로 쓴다. 이후 바이저와 함께 회전한다.
  - Physics 패널에 고른 축과 내적을 표시하고, `Re-pick helmet up` 버튼으로 다시 고를 수 있다(똑바로 앉은 자세에서 누른다).
  - 카메라는 여전히 쓰지 않는다.
- **정지 상태에서 두꺼운 trail이 없는 것:** 정지·무풍에서는 중력만으로 r ≥ 1.08 mm(코팅) 방울만 미끄러진다. Heavy Rain 30 s 정지에서도 이 크기는 드물다(히스토그램 1.03 mm 구간 41개). 그래서 trail의 원천이 거의 없다.
  - 해당 방울은 trail 깊이 약 0.1 mm로 그려져야 한다. trail 전용 문턱으로 이번 빌드에서 다시 확인한다.

### 60.7 rev47j — 수막 dewetting과 rivulet trail
- 상세: `docs/RAINFX_V2_REV47J_REVIEW.md`.
- **고속 흐림막:** 해상되지 않은 비가 0.11 mm 수막으로 쌓여 바이저를 덮었다. 부분 젖음 표면에서는 이 수막이 안정하지 않다. 셀 평균 0.04 mm 이상이면 셀당 4 /s 사건으로 방울이 된다(빈 셀은 탄생, 방울이 있으면 합류). cells와 field가 같은 해시로 판정해 질량을 보존한다. 수막 표시 문턱은 0.08/0.20 mm다.
- head drop과 기존 pearling 탄생은 질량을 만들어 냈다. 둘 다 제거했다.
- 산란 베일은 방울 위에 그리지 않는다. 수막 흡수는 두꺼운 시트에서만 일어난다.
- **trail:** 새 `trail` 패스가 field 텍셀마다 중심선(점, 방향, 반폭)을 저장한다. visor는 3 × 3 텍셀에서 가장 가까운 선을 원기둥 렌즈 커널로 방울 합집합에 넣는다(tan θ = 2 h0 / hw).
  - 폭 0.5 r, 증발 0.003 mm/s.
  - pearling은 셀당 0.1 /s이고 질량을 보존한다. 선 위에 방울을 남긴다.

### 60.8 rev47k — 흐르는 trail (rev47j 리뷰)
- 상세: `docs/RAINFX_V2_REV47K_REVIEW.md`. 형상 계획: `docs/RAINFX_V2_SHAPE_STATE_PLAN.md`.
- **rev47j 결과:**
  - 흐림막이 사라졌다(수막 덮임 0.6 %).
  - 서 있는 물은 32 μm, 머무름 시간은 0.14 s로 늘었다.
  - trail이 유리 막대처럼 영구히 남았다.
- **rev47k:**
  - trail은 고정 깊이 0.02 mm 위의 초과분만 수막 법칙을 선 방향에 투영한 속도로 자기 선을 따라 흐른다(semi-Lagrangian). 잔류선은 셀당 0.6 /s로 점선 방울로 끊긴다(질량 보존).
  - 경사 상한은 0.45, trailRMin은 0.2 mm다.

### 60.9 rev47l — trail 규칙(Ca 문턱)과 runback 속도
- 상세: `docs/RAINFX_V2_TRAIL_RULES.md`. 형상 표본: `docs/RAINFX_V2_SHAPE_STATE_PLAN.md` §6.
- **버그:** runback 속도 `clamp(·, vMax 0.08, runbackMax 0.06)`는 하한이 상한보다 커서 모든 runback 방울이 0.06 m/s였다. 이제 공기 하중의 초과분에 비례하고(크기 의존), 크리프 속도와 이어진다.
- **trail 조건:** Ca = U/72 > Ca\* = θr³/(9 ln(r/1 nm)), θr = 28° × (1 − 0.35 wet).
  - 폭 hw = 0.25 r √(1 − Ca\*/Ca), 깊이 h0 = min(5 r Ca^(2/3), 0.225 hw).
  - 질량 손실은 (4/3) h0 hw.
- pearling 비율 × (0.25 mm / hw): 가는 줄이 빨리 끊긴다.

### 61 rev48-S1 — 방울 형상 상태
- 상세: `docs/RAINFX_V2_SHAPE_STATE_PLAN.md` §7, 리뷰: `docs/RAINFX_V2_REV47L_REVIEW.md`.
- state는 [방울 | life | 형상] 3구획이다. 형상 = 텐서 (m₁, m₂), 굴곡(a2, a3), 휨.
  - 탄생 클래스 비율(휨 7 %, 합체형 5 %, 처짐 8 %)은 레퍼런스 표본에서 왔다. 이완은 크기와 이동에 따른다.
  - visor는 면적 보존 타원 + 휨 + 굴곡 커널로 그린다.
- 바람 노출: windVelocityKmh가 비어 있으면 windDirectionDeg와 트랙 방위로 대체한다. 패널에 출처를 표시한다.
- FXC X3571 경고 제거. 셰이더 검사기의 예약어 목록에 half/double/vector/matrix 등을 추가했다.

### 61.1 rev48-S1b — 리플레이 바람 출처
- 리플레이에서는 `sim.weatherConditions.wind`(컨트롤러 덮어쓰기가 반영된 값)를 방위와 트랙 방향으로 변환해 쓴다. 라이브에서는 `windVelocityKmh`를 쓴다.
- 관례 오프셋은 라이브에서 자동 보정해 저장한다(`windDirOffsetDeg`). 상세: `docs/RAINFX_V2_REV47L_REVIEW.md` §4.

### 62 rev48-S2 — 비스듬한 충돌 탄생
- 바람(S1b): 사용자 확인 완료. 라이브와 리플레이 모두 반영되고 관례 뒤집기는 필요 없다.
- 충돌 탄생: Vt/Vn에서 종횡비 A = min(1 + 0.35 Vt/Vn, 3)를 구한다. lamella와 파편은 하류로 늘인 타원에 놓고, 탄생 형상은 Vt 방향으로 늘린다.
- 처음 0.4 s는 빠르게 이완(recoil)하고, skid ≤ 0.05 m/s로 약 2 mm 미끄러진다.
- 상세: `docs/RAINFX_V2_SHAPE_STATE_PLAN.md` §8.
- 62.1 S2b: cells의 FXC X4000 경고 제거(단일 출구, 변수 초기화). recoil 창 0.8 s(정지 상태 세로 타원 과다).

### 62.2 탄생 장면 재학습과 S2′ 제안
- 레퍼런스 탄생 = 최종보다 2–4배 큰 납작한 불규칙 막. 0.15–0.3 s에 한쪽 끝으로 수축하고, 둘레에 위성 방울이 남는다. 기존 방울이 떠밀려 질주하고 trail을 남긴다.
- S2는 크기 변화가 없어 탄생이 보이지 않았다. S2′(spread 배율 f(t), 접촉각 f⁻³, 둘레 위성, 늘어남 축소, 합체 운동량 전달)를 제안했다.
- 상세: `docs/RAINFX_V2_SHAPE_STATE_PLAN.md` §9–10.

### 62.3 rev48-S2′ 구현
- splat spread f₀(We_n, 1.8–3.2)를 life.w에 기록하고, visor는 f(age)로 반지름 × f, 접촉각 ÷ f³, 굴곡 증폭, 상류 쪽 발자국 중심으로 그린다.
- 위성은 lamella 둘레에 놓고, 늘어남은 1.8 상한으로 줄였다. 합체 시 운동량을 전달한다(떠밂).
- 상세: `docs/RAINFX_V2_SHAPE_STATE_PLAN.md` §11.
- 62.4 S2′ 게임 리뷰: splat 수축, 위성, 떠밀린 질주를 확인했다. 수정(S2′a): splat rim 윤곽 = 접촉각 ÷ f^1.5 + flat-top β 0.85.
- 62.5 S2′b: 사용자가 찾은 수축 중간 splat 모양(f 1.3–1.5 = 접촉각 33–40°, flat-top 0.26–0.43, 발자국 ×1.3–1.5)을 기본 방울 프로파일로 쓰는 `baseSpread` 슬라이더(기본 1)를 추가했다. 시각만 바꾸며, 채택하면 shapeK와 합체 거리를 맞춘다.
- 62.6 S2′b 리뷰: 같은 모양의 방울은 크기만 달라도 질이 나오지 않는다. 핵심은 방울별 가변성이다(사용자). baseSpread는 유지하되 미확정. 다음 제안은 S2c(크기·seed·이력별 쉬는 퍼짐)와 S3(합체 형상)이다.
- 62.7 S2c: 방울별 쉬는 퍼짐 f_rest = base + 0.5·smoothstep(0.15, 0.8 mm, r)·(0.35 + 0.65 hash)·(1 + 0.3 wet). 작은 방울은 둥글고, 큰 방울은 방울마다 납작함이 다르다. 상세: SHAPE_STATE_PLAN §12.
- 62.8 rev48-S2d/S3:
  - 비대칭 캡(음영 높이 h(1 − k d), 큰 방울은 아래가 두껍고 작은 방울은 무작위 방향).
  - 합체 발자국 텐서 합성(평행축, 균형 쌍 땅콩 허리).
  - 사용자 기준: "모두가 같은 돔에 같은 음영이 아니어야 한다". 상세: SHAPE_STATE_PLAN §13.
- 62.9 S3b: 잘린 상과 tick의 원인은 ±2셀 그리기 창 초과였다. 커널 전체 범위를 창 안으로 축소한다. 합체는 그려진 발자국 반지름으로 판정한다(r2FootRadiusMM, visor와 같은 규칙과 창 상한).
- 62.10 rev48-S4:
  - 형상 기억(납작함 f를 상태에 저장하고, 셀 해시를 제거).
  - splat arrest(수축 중간 형태를 유지).
  - 정지 = 유지, 미끄럼 = 운동 타원(헤드 앞쪽 두꺼움, 테일 teardrop).
  - 흐르는 헤드는 합체 텐서를 적용하지 않는다. 흐르는 방울의 팝인, 회전, 1프레임 반짝임의 원인 세 가지를 제거했다.
  - 상세: SHAPE_STATE_PLAN §14.
- 62.11 S4b: 합체 순위, 위치, 승자를 발자국 면적 (r f)²으로 정한다(Laplace 압력: 넓고 납작한 쪽으로 흡수). 이동은 운동량 보존이다. 흐르는 헤드가 앞의 넓은 방울에 닿으면 그 자리에서 새 헤드로 이어진다. S5(사건 기반 형상 물리 E1–E8)를 제안했다. 상세: SHAPE_STATE_PLAN §15.
- 62.12 S4c + S5 E7/E1:
  - 발자국 = 물의 반지름이다(f는 프로파일만 바꾼다). 넓게 그려지는 것은 충돌 직후 splat뿐이다.
  - 중력 처짐 타원(1 + 1.2·Bo)으로 이완한다.
  - 충돌 arrest는 국소 고정 노이즈를 따르고, K/K₀에 따라 찢어진 테두리 a3가 남는다.
  - 상세: SHAPE_STATE_PLAN §16.
- 62.13 S5 E3/E6:
  - 늘어진 방울은 출발할 때 길이를 유지한 채 진행 방향으로 회전한다(slug, 0.6 s).
  - 정지 방울은 중력 처짐 + 헬멧 공기 늘어남(1 + 0.08 We_air ≤ 1.6)으로 이완한다.
  - E8 분리는 보류. 상세: SHAPE_STATE_PLAN §17.

### 62.14 S5 E3·E6 리뷰 → S6 흐름 변형 검토 (2026-10-29)
- FXC X4000(`r2ShapeRelax` early return)을 단일 출구로 고쳤다.
- 사용자 확인: E3 slug 정렬과 E6 바람 늘어남 모두 적절하다.
- S6 검토(`RAINFX_V2_SHAPE_STATE_PLAN.md` §18, 프로토타입 `docs/prototypes/rainfx2_s6_flow_proto.*`). 세 가지 모두 상태와 텍스처 읽기 추가 없이 ALU 수십 개 수준이다.
  - F1 결함 장 기울기 조향 + stick-slip: 지그재그.
  - F2 장축–진행 방향 어긋남 기반의 꼬리 지연, 초승달 bend, 바깥 앞 정점, 40° 끊김.
  - F3 합체 납작함을 발자국 넓이 초과로 계산. 진동 단계는 프레임 이하 현상이라 제외.

### 62.15 rev48-S6 구현 (2026-10-29)
- F1 결함 장(헤드 위치의 stick-slip 고정과 기울기 조향, meander 0으로 대체).
- F2 장축 회전(꼬리 지연), 늘어남, 바깥 초승달 bend, 40° 끊김, visor 바깥 앞 정점.
- F3 합체 납작함을 발자국 넓이 초과로 계산.
- 상태와 텍스처 읽기는 늘지 않았다. 세부는 SHAPE_STATE_PLAN §19.

### 62.16 rev48-S6b (2026-10-29)
- **위빙 글리치:** S6 조향 이득이 과다했다(|lat| 5–18, 클램프 시간 ~80 %). 방향이 ±27°로 뱅뱅 전환됐다.
  - 고정력 비대칭 / 구동력 법칙으로 교체했다: defK · defPin · ΔD_side · drive / √max(1, 2r/defMM). defK 5.
- **회전 형태:** 타원 전체 회전 + 대칭 bow → 꼬리 장축 지연 + 헤드 절반 갈고리(한쪽 bend, mode 비트, hookK 2 · tan Δ).
  - 30° 회전 시 완만한 ㄱ이 되고, 꼬리가 따라오면서 펴진다.
- 세부: SHAPE_STATE_PLAN §20.
- S6b 리뷰: FXC OK. 위빙이 정상 수준이 되었고, 헤드 갈고리 회전을 사용자가 확인했다. 기본값을 확정했다(§20.3).

### 62.17 rev48-S6c E8 꼬리 분리 (2026-10-29)
- r2Predict 분리 사건: (A) A ≥ 2.6 또는 (B) 미끄러지던 방울의 40° 초과 꼬리 끊김. 6/s, r ≥ 0.45 mm.
- 자식은 꼬리 끝 접촉 거리 바로 바깥에 놓인다. 질량이 정확하고, gather 창을 벗어나면 사건을 취소한다.
- 부모는 e × 0.55가 되고 곧게 펴진다. claim은 갓 분리된 자식의 sweep 합체를 제외한다. 세부는 SHAPE_STATE_PLAN §21.
- 62.17a S6d: 분리 조각 청록 하이라이트(관찰 도구), 부모 방향 목(shpNeckK 1.5, 0.12 s 수축). 이전 FXC 실패는 수정본이 폴더에 기록되지 않은 탓이었다.
- 62.17b S6d 리뷰: 분리 조각이 운동 방향에 맞게 경로를 따라 생기고, 늘어졌다 당겨지는 형태라 자연스럽다(사용자 확인). E8 기본값을 유지한다. 선택 개선은 (A) 분리를 장축 정렬 30° 이내로 제한하는 것이다.

### 62.18 rev48-S7 Furmidge 폭 고정력 (2026-10-29)
- 고정력 폭을 2r에서 형상 발자국의 힘 수직 폭으로 바꿨다(w/2r = 1/√(c²/A + A(1 − c²)), 0.6–1.6). footPinK 1.
- 길쭉한 처짐 방울과 슬러그는 더 쉽게 미끄러지고, 가로로 늘어난 방울은 더 버틴다. 세부는 SHAPE_STATE_PLAN §22.
- 62.18a S7 리뷰: 정지 상태가 자연스러워 footPinK 1을 확정했다. 주행, 바람 종합 이동 방향 반응 개선은 사용자가 후속 과제로 예정했다.

### 62.19 형상 단계 마감 (2026-10-29)
- baseSpread 1.0을 확정했다. 작은 방울 반짝임은 없었다(사용자 확인).
- S1–S7을 확정했다(SHAPE_STATE_PLAN §23). 후속 과제는 주행과 바람 종합 이동 방향 반응이다.
