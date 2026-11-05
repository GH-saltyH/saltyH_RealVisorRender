# RealVisor / RainFX v2 성능 분석 기반 (PERF-1, 2026-11-06)

- **사용자 측정:** 앱 사용 전후 FPS가 87 → 62이다(약 4.6 ms / frame 증가).
- **요청:**
  - RainFX를 KN5 메쉬 Visible 토글(GLASS_RAINFX)과 함께 켜고 끈다. off일 때 파이프라인 전체를 건너뛰어 CPU / GPU 오버헤드를 0으로 만든다(비용 평가 기준선).
  - 앱 전체를 프로파일링하고 불필요하게 무거운 부분을 제거한다.
- **원칙:** 측정으로 근거를 확보한 뒤에 제거한다(의심 구역 수정 지양).

## 1. RainFX v2 on / off 게이트
- `rainDynamicSceneCopyState.rainfx2Active()`(realvisor.lua)가 v2를 실행하는 조건: v2 설정 enabled이고 KN5 탭에서 GLASS_RAINFX가 Visible.
- **off(메쉬 숨김)일 때:**
  - `RainFX2 sim`(onSceneReady)을 건너뛴다.
  - `RainFX2 draw`(색 / 깊이)를 건너뛴다.
  - `core:dispose()`로 GPU 자원을 전부 해제한다(cells / field / trail / lamella / claims / sheet / nuc / bead / big / metrics 캔버스, 굴절 소스, 물방울 메쉬).
- **다시 Visible로 켜면** ensureResources / ensureMesh가 재생성한다. visor는 마른 상태로 시작한다.
- legacy RainFX는 v2가 enabled인 동안 계속 꺼 둔다(arbitrate는 변경 없음).
- **수정:**
  - R2:dispose가 FS, SK, NM, LM, BM, BG를 해제하지 않던 누수를 고쳤다.
  - 진행 중인 readback 플래그(metricsBusy / sizesBusy)를 초기화한다.

## 2. 프로파일러 (전체 앱)
- 파일 맨 앞에서 `render.on` / `render.onSceneReady`를 감싼다. 이 스크립트가 등록하는 모든 콜백이 프로파일링 중에 측정된다.
  - Render Stats: `RV <event> L<정의 줄>`(CPU + GPU, render.measure; 중첩된 측정은 바깥 1단계만)
  - RainFX 탭 'Performance profile' 표: 콜백별 CPU ms(EMA), peak, 상위 30개
  - script.update / windowMain CPU 시간도 같은 표에 나온다.
- off일 때 비용은 콜백당 boolean 1회이다. 토글은 기존 `RAIN_PERFORMANCE_PROFILING`이다.
- RV_PROF는 전역이다. main chunk가 Lua 지역 변수 한도 200에 도달해 있어 지역 변수를 추가할 수 없다(texlua로 확인).

## 3. 근거 있는 제거 (이번 단계)
- **nativeCapture 모델의 `findMeshes('*')` 캐시:**
  - 매 호출마다 씬 쿼리였다. nativeCaptureHide(main.root.opaque, mirror, script.update) / nativeCapturePrepare에서 모델 종류마다 프레임당 여러 번 실행되었다.
  - 로드할 때 한 번 만든 목록을 재사용한다. 동작은 같다.

## 4. v2 on, legacy off 상태에서 매 프레임 남는 작업 (정적 인벤토리, 측정으로 판정할 후보)

| 콜백(정의 줄은 원본 기준) | 내용 | 비고 |
|---|---|---|
| glassFallback (main.smoke / root.transparent) | dynamic::hdr 전체 해상도 RGBA16F 복사 + 밉 체인, glass stack pre / post, RainFX2 draw | 소스는 glass와 v2가 공유 |
| RainFX2 draw 내부 prepareSource | 0.5배 해상도 housing-free 소스 + 밉 | v2 전용 |
| optics (RAIN_VISOR_OPTICS_ENABLED) updateBake / ExternalProbe / NativeSource | E2 / E3 광학 | 매 프레임 |
| nativeHousingEnsure / nativeHousingSceneUpdate / nativeGlassPrepare | 하우징 / 유리 네이티브 캡처 | 매 프레임 |
| e1MultiUpdate / e1PrimaryResolveUpdate | E1 소스 | 매 프레임 |
| main.track.opaque (motion test, beginMainView) | visor 변환 | 저비용 예상 |
| script.update | materialSettings flush, physicsInputs, nativeGlassState, visorLayerSceneHide | CPU |

다음 단계: 사용자가 프로파일 표와 Render Stats 값을 제공하면 상위 항목부터 근거 기반으로 제거 / 축소한다.

## 5. PERF-1 리뷰 반영 (2026-11-06)

### 5.1 측정 (Heavy Rain, 사용자)

| 상태 | FPS | frame time (ms) |
|---|---|---|
| 해제 | 87 | 11.5 |
| 켬, FX 없음 | 81 | 12.3 |
| + EXT + E4 | 80 | 12.5 |
| + INT + E7 | 77–78 | 12.9 |
| + E2 / E3 | 77–78 | 12.9 |
| + RainFX2 | 63 | 15.9 |

- **RainFX2 ≈ 3.0 ms**이다(앱 전체 4.4 ms의 2/3). glass 레이어 전부(E1–E7)는 ≈ 1.4 ms이다.
- **다음:** 프로파일러를 켜고 `RainFX2 sim/<pass>`(cells, claim, merge, field, trail, sheet, …)와 `RainFX2 draw/source`를 측정한다(PERF-2: 패스별 Render Stats). 상위 패스부터 줄인다.

### 5.2 LIFE-1: RainFX on / off 재개 버그
- **증상:** GLASS_RAINFX를 숨기면 E2 / E3도 사라진다. 다시 켜면 E2 / E3만 돌아오고 RainFX는 돌아오지 않는다.
- **원인(코드 근거):**
  - **재개 불가:** R2:drawParams가 첫 호출의 `mesh = self.mesh`를 캐시했다. suspend 후 재생성된 메쉬 대신 해제된 메쉬로 그렸다. render.mesh 실패 → `self.err = 'Draw: …'` → enabled() false가 영구적으로 유지된다.
  - **E2 / E3 동반 소실:** PERF-1은 숨김 처리(dispose)를 렌더 콜백 안(rainfx2Active)에서 했다. 이것이 glassFallback의 같은 pcall 블록 안에서 실행되어, 거기서 난 오류가 뒤따르는 `visorSceneStack('post')`(INT, E2 / E3, EXT)를 건너뛰게 할 수 있었다.
- **수정:**
  - 전환은 script.update의 `rainfx2Lifecycle()`에서만 한다(렌더 밖). 숨기면 `core:suspend()`, 보이면 `core:resume()`(err와 그리기 캐시 초기화)이다. 렌더 콜백은 `rainfx2Active()` 조회만 한다.
  - RainFX draw / depth draw는 각자 pcall로 감싼다. 실패해도 glass post 스택은 항상 실행된다.
  - dispose는 항목별 가드를 두고 모든 필드를 비운다(paramsColour / Depth, passSource / Seed, 크기 투표, readback 플래그 포함). drawParams는 매 호출 `t.mesh = self.mesh`이다.

### 5.3 GLASS-ORDER-1: E2 / E3이 EXT_FX 위에서 EXT까지 굴절
- **이전(s55–s57):** COAT → rain → INT(E2 / E3, 캡처 = post 시작 시점) → EXT(마지막, 'band owns the final overlap')였다. 캡처에 밴드가 없어서 EXT를 위에 강제로 그렸다.
- **이후:** COAT → rain → EXT → INT(E2 / E3)이다.
  - INT 옵틱스 / E2 / E3 캡처(dynamic::hdr)는 첫 kind 3 항목 직전, 즉 EXT를 그린 뒤에 찍는다. 밴드가 캡처에 포함되어 함께 굴절된다.
  - INT 패스의 밴드 재구성은 이미 꺼져 있다(kind 3 gLayerBandOpacity 0). clear-glass delta(opticalImage − base, α 0)는 base가 실제 대상과 같아져 정확해진다.
  - 하늘 투명 문제는 예전 LDR / 톤맵 캡처 때문이었다. 지금 캡처는 HDR(dynamic::hdr)이고 같은 타깃이다.
- **비교:** `cfg.RUNTIME.RAIN_VISOR_LAYER_EXT_LAST = true`(그리고 vl.defs 재생성)로 예전 순서를 복원한다.

### 5.4 BAND-SDF-1: EXT_FX 밴드 경계 앨리어싱 / 울퉁불퉁
- **분석:**
  - `ext_txBand.png`(2048×512)의 알파는 사실상 이진이다. 13단계이고 전이 텍셀은 0.07 %이다.
  - 셰이더는 알파 0.064–0.104 smoothstep을 쓴다. 그래서 텍셀 계단과 그려진 요철이 화면에 그대로 나오고, 문턱이 낮아 밴드가 반 텍셀 부풀었다.
  - 경계가 메쉬 면 경계가 아니라 텍스처 경계이므로, 화면 해상도로 보는 visor(약 0.3 mm / 텍셀)에서는 계단이 수 픽셀로 보인다.
- **조치(셰이더 + 텍스처, 자동):**
  - `ext_txBand_sdf.png`를 만든다. 4배 업샘플 후 σ 1.5 텍셀로 윤곽을 다듬고 0.5 등고선을 취한 뒤, signed distance / 12 텍셀 + 0.5를 알파에 넣는다. RGB는 밴드 색을 바깥으로 확장한다.
  - 셰이더는 `band = saturate((a − 0.5) / fwidth(a) + 0.5)`이다. 확대 / 축소 / 밉에 관계없이 경계가 1 화면 픽셀 폭이다.
  - 윤곽 변화는 186 텍셀로 요철과 계단만 바뀌었다. 끄려면 `RAIN_VISOR_LAYER_BAND_SDF = false`.
- **Blender 비교:**

  | | SDF(이번) | Blender 면 / 재질 분리 |
  |---|---|---|
  | 경계 정확도 | 텍셀 해상도 내 매끈한 곡선(0.3 mm 이하) | 기하 정확(벡터) |
  | AA | 셰이더 analytic 1 px | 기하 에지는 MSAA / TAA(DLSS)에 의존한다. 같은 표면의 재질 경계라 셰이더 AA 불가 |
  | 작업 | 없음(자동 생성, 재생성 스크립트) | 메쉬 분할, UV, KN5 재빌드, atlas / verify 해시 갱신 |
  | 비용 | 0(fwidth 1회) | draw 1회 추가(재질 분리 시) |
  | 형상 수정 | 윤곽은 원본 마스크를 따름 | 밴드 모양 자체를 다시 그릴 수 있음 |

  - **권장:** SDF로 충분하다. 밴드 모양 자체를 바꾸고 싶을 때만 Blender에서 면을 분리한다. 그 경우에도 SDF 텍스처를 새 마스크에서 다시 굽는 것이 AA에 유리하다.
