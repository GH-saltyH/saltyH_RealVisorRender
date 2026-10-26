# RainFX v2 (셀-gather) 개발 착수 준비

2026-10-25. 근거 설계: [RAINFX_CSP728_RE2_OPTIMAL_PLAN](RAINFX_CSP728_RE2_OPTIMAL_PLAN.md).
이 문서는 **브랜치 생성 전 기초 준비**의 결과다. 코드·자산은 아직 바꾸지 않았다.
기존 구현을 읽고 재사용할 계약, 지울 찌꺼기, 실행 중 충돌 요인, 브랜치 운용 순서를 정한다.

## 1. 확정된 방향 (사용자 결정 2026-10-25)

- **A3 셀-gather를 주 구현, A4 절차적 미세 디테일을 보조로** 쓴다.
- CSP RainFX는 와이퍼가 달린 앞유리를 표현하는 방식이다. 우리는 **바이저 표면의 특수성**을 따른다.
  **첨부한 영상 3개의 물 효과가 항상 레퍼런스다**(C 약한 비 / B 고속 중간비 haze·닦임 / A 물보라·강한 굴절).
- CSP 화면 방울(카메라 효과에 가깝다)은 충돌을 막기 위해 **앱 단위에서 의도적으로 끄는 기능**을 둔다.
- 디포커스, 반전 렌즈 + mip, LOD haze + 베일로 **화질을 싸게 얻는 기법**을 핵심으로 쓴다.
- v2는 현재 바이저 RainFX(legacy 경로 + P0 프리뷰)를 **완전히 대체**한다. 같은 효과를 더 빠르게 낼 방법이 있으면 기존 방식보다 그쪽을 우선한다.

## 2. 기존 구현에서 재사용할 계약

### 2.1 메쉬·UV·마스크 (s61, [KN5 4:1 migration](RAINFX_KN5_4_TO_1_MIGRATION.md))

- 대상 메쉬는 `GLASS_RAINFX`(dummy 원본은 native 패스에서 숨김, 커스텀 패스는 editor Visible이 제어).
- raw UV는 U∈[0,1], V∈[−1,0]. 샘플링은 `(U, V+1)`. 4:1 아틀라스. **wrap 없음**.
- `texture/RAINFX_ObjNormal_BoundaryMask.dds` 4096×1024: RGB = object normal, **A = 유효 표면**.
  구멍·바깥 경계·끊긴 영역은 흡수 경계(방울 소멸)다. 검은 RGB로 유효성을 판단하면 안 된다.
- 모델/마스크 SHA256 게이트(`surface.verify`, `rain-surface-v2`)를 v2도 그대로 통과해야 한다(`rain_surface.lua:validate`).

### 2.2 표면 메트릭 = 실제 운동 방향 적용 방법

- `texture/RAIN_GEOMETRY/du.dds`, `dv.dds` (2048×512 RGBA32F): RGB = dP/dU, dP/dV (**KN5 로컬 m / raw UV**).
  `du.A` ≥1이면 유효하며, 값은 마스크 텍셀 단위의 보수적 안전 이동거리다. `dv.A` = 코팅 커버리지.
- 힘(오브젝트 공간) → UV 속도: **(JᵀJ)⁻¹Jᵀ·F** (`rainMetricProject`). UV 회전·전단·스케일이 정확히 반영된다.
  minimal-stretch UV라서 형태가 월드 x/y와 1:1이 아니어도 이 투영으로 물리 방향이 맞는다.
- 실측(이번 계산): 유효 텍셀 48.9%, |dP/dU| 중앙값 0.602 m/U (p5–p95 0.51–0.69), |dP/dV| 0.146 m/V
  (0.126–0.157), 표면적 0.0423 m², 코팅 63%. **UV 스트레치 편차가 ±15% 수준이라 UV 격자 셀-gather에 유리하다.**
- 프로파일 스케일은 균일 스케일만 지원한다(현재 카메라 노드 구조).

**v2 결정:** legacy "reference unit"(`RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM`)은 승계하지 않는다.
v2는 m/UV = du·profileScale을 직접 쓰는 **순수 SI**로 간다. `rainSurfaceMetric.hlsl`의 함수는 재사용하되
`gRainMetersPerUnit` 대신 v2 전용 상수를 바인딩한다.

### 2.3 힘 입력 (기존 CPU 계산)

- 관성: `car.acceleration`(차량 로컬 G) → side/up/look 기저로 월드 변환 → ×9.81 → 부호 반전(`updateRainFlow`).
- 중력: 월드 (0,−9.81,0). 공기: 차량 속도·바람, 노출은 object normal. S64의 downward 모드(하향 성분은
  물리 downhill로 대체, 횡 성분은 유지)는 결과 검증이 남아 있으므로 v2에서는 옵션으로만 승계한다.
- 월드→오브젝트 변환에는 바이저 노드 체인(NeckFX/G-force 포함) 역회전을 쓴다.

### 2.4 렌더 패스·레이어 관계 (scene stack, [VISOR_LAYER §17–§21](RAINFX_VISOR_LAYER.md))

`main.track.transparent`에서 순서는 계약이다.

1. **Glass pre**: 하우징 opaque(depth write) → `GLASS_COAT_FX` premultiplied, depth read-only.
2. **Rain colour**: `GLASS_RAINFX`, BlendAccurate, depth read-only, cull none
   (메쉬는 render.mesh 직전에만 visible, 직후 다시 hide).
3. **Glass post**: `GLASS_EXT_FX`(밴드가 방울을 가림) → `GLASS_INT_FX`. 반드시 depth pass **전에** 그린다.
4. **Rain depth-only**: 같은 메쉬로 젖은 곳만 depth를 쓴다(AlphaBlend, depth Normal). 나중에 그려지는 차량 유리·와이퍼가 방울 위에 블렌드되지 않게 하기 위함이다.

- 비가 꺼졌거나 준비 중일 때는 `glassFallback`이 1과 3을 그린다. 이때 장면 소스는
  `visorLayer.fallbackSource` = **`dynamic::hdr`의 RGBA16F 전체 해상도 복사 + 전체 mip**이다(뷰마다 1회).
- **v2는 이 fallbackSource를 굴절·haze 소스로 그대로 쓴다.** 실제 프레임이라 legacy의 GeometryShot +
  톤 패스(SHOT_TONE, "페인트 느낌" 보정)가 필요 없고 추가 복사도 없다.
- 뷰 가드: `renderViewKey()` / `offscreenCaptureActive`. 시뮬은 프레임당 1회만 돌리고,
  오프스크린 캡처(E1 native capture, 광학 bake) 안에서는 절대 실행하지 않는다. VR·미러는 그리기만 한다.
- native glass(`nativeGlass`, s63)가 외부 픽셀을 소유하는 규칙과 `rainOcclusionUpdate`(R32G32F 장면/native depth)는
  필요할 때 재사용 후보로 둔다. 하드웨어 depth read-only로 충분하면 v2에서는 생략한다.

### 2.5 프로젝트 제약

- `realvisor.lua`(20,129행, `RAIN_*` 설정 키 640종)는 LuaJIT 청크 local 한계 때문에 전역 테이블
  `rainDynamicSceneCopyState`를 쓴다. v2는 **별도 모듈 파일 + 단일 핸들**로 붙여 이 한계를 건드리지 않는다.
- main의 UTF-8 BOM/CRLF를 보존한다.
- **소스 일부가 게임 설치본과 hard link로 공유된다.** 브랜치를 만드는 것 자체는 파일을 다시 쓰지 않는다.
  그러나 내용이 다른 브랜치로 checkout하면 git이 파일을 새로 만들면서 hard link가 끊긴다 → 브랜치 전환 뒤 링크를 확인해야 한다.
- 현재 HEAD: `codex/rainfx-physics-weather`. 작업 트리가 깨끗한지(미커밋 변경 여부)는 셸 접근이 없어 확인하지 못했다.

## 3. v2 구조를 이 메쉬에 맞춘 값

|자원|해상도/형식|비고|
|---|---|---|
|셀 상태 S0/S1|**512×128 RGBA32F** 핑퐁 (셀 ≈1.18×1.14 mm, 유효 셀 ≈32k)|x,y = 셀 내 위치, z = 체적 m³, w = 나이/상태. 속도는 매 스텝 힘에서 다시 계산|
|표면장 F0/F1|1024×256 RGBA16_UNorm|흔적 T, haze M, 수막 W, 타이머|
|광학 O|1024×256 RGBA8 + mips|디포커스 LOD 샘플|
|메트릭|기존 du/dv/mask 재사용|추가 bake 없음|

- gather 반경 R=2(25 tap), 서브스텝 1–4(최대 속도 기준 적응). 도착 셀이 무효(mask/du.A)면 소멸.
- 그리기는 2.4의 2·4단계 자리에 v2 셰이더로 `render.mesh`를 호출한다. 장면 소스는 fallbackSource.
- 날씨 입력은 `rain_environment.lua`(순수 입력 해석기)를 재사용하고, v2 매핑(RE2 문서 §4)을 별도 모듈로 둔다.
- CSP 화면 방울: `ac.INIConfig.cspModule(ac.CSPModuleID.RainFX)`로 `[SCREEN_DROPS] STYLE_COCKPIT`을 감지한다.
  끄는 기능은 **opt-in 토글**로 만든다. 사용자 설정 override(Documents/Assetto Corsa/cfg/extension/rain_fx.ini)를
  백업한 뒤 수정하고, 앱 종료 시 복원한다. CSP 설정 변경 API가 없어서 이 방법을 쓰는데,
  live reload 여부(`ac.onCSPConfigChanged`)와 전체 IO 권한은 **게임에서 확인해야 한다**. 안 되면 UI 안내로 대체한다.

## 4. 정리 대상: 찌꺼기와 충돌 요인

### 4.A 즉시 제거 가능 — 참조 0 확인

루트의 오래된 P0 사본 18개. `realvisor.lua`와 `docs/runtime/s282/*`가 참조하지 않는다.
s282는 자기 폴더의 사본을 `dofile`로 직접 불러온다.

```
rain_fixed_cadence.lua  rain_fixed_cadence_v2.lua  rain_fixed_input.lua
rain_interval_admission.lua  rain_interval_admission_v2.lua  rain_interval_admission_v3.lua
rain_live_capture.lua  rain_preview_csp.lua  rain_preview_executor.lua  rain_preview_file_inputs.lua
rain_preview_intervals.lua  rain_preview_recurrent.lua  rain_preview_stream.lua
rain_product_capture.lua  rain_product_pipeline.lua  rain_product_runtime.lua
rain_rigid_pose.lua  rain_time_queue.lua
```

(`CURRENT_STATUS.md`에는 "루트 중복 정리됨"이라고 적혀 있지만 실제 폴더에는 남아 있다 → 문서와 실제가 불일치.)

### 4.B 실행 충돌 — v2가 켜져 있으면 반드시 꺼야 함

|요소|위치|조치|
|---|---|---|
|legacy rain 준비|`render.onSceneReady`(물리·birth mask·wipe mask·smear·micro rebake)|`RAIN_ENABLED=false` 강제|
|legacy rain 그리기|manual draw callback + `main.track.transparent` 블록|같은 스위치로 off. glassFallback이 유리 스택을 계속 그림|
|P0 연속 프리뷰|`docs/runtime/s282/rain_product_host.lua`|로드하지 않음|
|미러 water pass|`mirror.track.transparent`(legacy water 필드를 읽음)|off. v2 water-only 미러는 나중에 결정|
|archived overlay / probe|`RAIN_VISOR_OVERLAY*`, `RAIN_DYNAMIC_STAGE_PROBE`|기본 off 유지|
|CSP 화면 방울 / Neck FX helmet|CSP 설정|3장의 opt-in 토글 / UI 안내|

### 4.C 이름은 rain이지만 계속 쓰는 공유 인프라 — 지우면 안 됨

`rainDynamicSceneCopyState`(전역 네임스페이스), `visorSceneStack`/`glassFallback`/`visorLayer*`,
`shaders/rainVisorLayer.hlsl`(유리 스택·E 광학 셰이더), `renderViewKey`/`captureUpdate`,
`native_glass_*.lua`, `visor_optics.lua`, `material_settings.lua`, `rain_surface.lua` +
`shaders/rainSurfaceMetric.hlsl` + `texture/RAIN_GEOMETRY/{du,dv,position,surface.verify,...}`, `rain_environment.lua`.
→ v2 안정화 후 `visorStack`으로 개명·분리한다(R3).

### 4.D v2가 C/B/A를 통과한 뒤 일괄 삭제 (R2)

- `realvisor.lua`의 legacy rain 구간과 v2가 쓰지 않는 `RAIN_*` 키(설정 ini 포함).
- `docs/runtime/s282/` 전체, `runtime_dependencies.json`의 prototypes 37 + probes 2.
- 루트 `rain_birth_gpu.lua`, `rain_birth_model.lua`, `rain_film.lua`, `rain_trails.lua`, (재사용하지 않으면) `rain_physics_units.lua`.
- `shaders/` legacy: `rainBirth*`, `rainFilm*`, `rainTrail*`, `rainMetaEntry`, `rainStateEntry`,
  `rainPhysicsSI`, `rainVisorDynamicDrop`, `rainVisorScreen`, `rainMirrorWater`. `rainVisorOptics`는 소비처를 확인한 뒤 결정.
- `texture/RAIN_BIRTH/`, `texture/RAIN_FILM/`, `RAIN_GEOMETRY/spawn_sites.dds`·`*_transfer.npz`(v2가 쓰지 않으면), smear 마스크.
- git 이력과 기존 복구 ZIP에 남으므로 별도 보관은 하지 않는다.

삭제 전에는 `check_installation.py`/`check_project.py`의 manifest를 함께 갱신해야 한다.
지금 바로 지우지 않는 이유: v2가 화면을 낼 때까지 A/B 비교(토글 하나)가 레퍼런스 대조에 유용하다.

## 5. 브랜치 운용 제안

- 기준: 현재 HEAD(`codex/rainfx-physics-weather`)에서 작업 트리를 커밋/정리한 뒤 생성.
  이름 제안: `codex/rainfx-v2-cellgather`.
- 커밋 순서:
  1. **C0** 착수 문서(이 문서·RE2) + 4.A 루트 찌꺼기 18개 제거 + CURRENT_STATUS 불일치 수정.
  2. **C1** `rainfx2/` 모듈 골격 + realvisor.lua 접점(v2 on이면 legacy 강제 off, glassFallback의 pre/post 사이에
     v2 colour, post 뒤에 depth-only, onSceneReady에 1회 시뮬) + v2 UI 섹션.
  3. **C2 = M1** P1 셀 시뮬 + P3 광학 + P4 합성, 고정 입력. 첫 게임 확인: 방울이 보이고 안정적인지,
     밴드·하우징 순서, depth pass, `render.measure` 수치.
  4. **C3** P2 표면장 + 날씨 매핑 → C/B.
  5. **C4** 수막 W + 스프레이 추정 → A.
  6. **C5** CSP 화면 방울 opt-in 토글.
  7. **C6 (R2)** legacy 일괄 삭제. **C7 (R3)** 공유 인프라 개명.
- 모듈 배치(제안): `rainfx2/init.lua`(공개 핸들: `simulate(sim)`, `drawColour(src)`, `drawDepth()`, `ui()`),
  `rainfx2/weather.lua`, `rainfx2/csp_screen_drops.lua`, `rainfx2/shaders/{common,cells,field,optics,visor}.hlsl`.
  설정 키는 `RFX2_*` 접두사로 분리해 640개 legacy 키와 섞지 않는다.

## 6. M1 게임 확인 체크리스트

- fallbackSource가 유효하고 mip이 있는지(필요하면 `txPreviousFrame` mip 존재도 1줄로 확인해 복사 절감 여부 판단).
- `GLASS_RAINFX` 그리기 순서: 하우징이 가장자리를 가리는지, 밴드가 방울을 가리는지, 이중 유리가 없는지.
- depth-only 패스 이후 차량 유리·와이퍼가 방울 위에 블렌드되지 않는지.
- `render.measure`: P1/P2/P3/P4 GPU ms, CPU ms. 목표: GPU ≤0.5 ms @1440p, CPU ≤0.1 ms, readback 0.
