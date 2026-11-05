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

## 6. PERF-2 결과와 PERF-3 (2026-11-06)
- **사용자 확인:**
  - LIFE-1(재개)과 E2 / E3 유지를 확인했다.
  - GLASS-ORDER-1은 의도대로 동작한다. 한계: 상단 극단 곡면에서는 굴절 샘플이 밴드 밖(배경)으로 나간다. 심각도는 낮다.
  - BAND-SDF-1: E2 / E3을 덧입히면 앨리어싱과 요철이 모두 사라진다. EXT 단독에서는 약간 남는다.
- **CPU 프로파일(RainFX2 포함, 1.79 ms / frame, 24 콜백):**

  | 콜백 | CPU (ms) | 내용 |
  |---|---|---|
  | sceneReady L14929 | 0.56 | RainFX2 sim(Lua 쪽 패스 제출) |
  | sceneReady L14568 | 0.42 | optics updateBake / ExternalProbe / NativeSource |
  | main.smoke L14943 | 0.36 | glassFallback(HDR 복사, glass 스택, RainFX2 draw) |
  | windowMain | 0.24 | UI(창이 열려 있을 때) |
  | script.update | 0.09 | |

  - CPU 합계 1.8 ms로는 RainFX2의 FPS 손실(≈ 3 ms)을 설명하지 못한다. 대부분 GPU이다. 패스별 GPU 값(Render Stats `RainFX2 sim/*`, `RainFX2 draw*`)이 다음 근거이다.
- **PERF-3(구조적 중복 제거, 결과 동일):**
  - cells 패스는 출력 텍셀(512×128 × 3: drop / life / shape)마다 5×5 창의 모든 방울에 r2Predict(힘 균형, 결함장, 경계층, E8 분할, 증발 …)를 다시 계산했다. 방울 하나가 substep마다 최대 75번(25 창 × 3 third) 계산되었다.
  - r2Predict는 원천 셀 입력에만 의존한다(수집 픽셀과 무관). 그래서 새 패스 `predict.hlsl`이 방울당 3 텍셀(dest / vol / alive + moved, life, E8 child)로 한 번만 계산한다. cells는 그 값을 읽는다(같은 함수, 같은 입력이므로 비트 동일).
  - 추가 메모리: 3×512×128 RGBA32F = 3 MB. Render Stats에 `RainFX2 sim/predict`, `sim/cells`가 따로 나온다.
- **다음 후보(GPU 측정 후):**
  - cells의 충돌 5×5 루프(세 third 모두 실행)
  - field 5×5 수집
  - claim / merge 34 후보
  - visor draw(전체 화면 메쉬, 34 후보 루프)
  - 굴절 소스(0.5배 + 밉)
  - glass: HDR 전체 해상도 복사 + 밉 체인 2–3회(fallback / cachedScene / optics)

## 11. PERF-4 / 4b 회귀 원인 규명과 PERF-5 (2026-11-06)
- **사용자:**
  - 앱 리로드 후(프로파일러 off)에도 E7 글리치가 관찰되었다.
  - git으로 PERF-3 상태를 복원했고, 그 상태에서는 글리치가 없다. PERF-4 / 4b에서 생긴 충돌을 규명해야 한다.
  - 앞으로 최적화는 공유 / 종속 리소스의 충돌 지점을 철저히 검증한 뒤 반영한다.
- **복원 확인:** 장치의 realvisor.lua, rainfx2/init.lua, visor.hlsl, 체크 도구, 이 문서가 PERF-3 산출물과 바이트 단위로 같다(CRLF 정규화 후).

### 11.1 근본 원인: CSP 템플릿 예약 텍스처 레지스터 충돌(PERF-4)
- CSP는 Lua 셰이더의 텍스처를 t0부터 순서대로 선언한다. 템플릿 include는 그 위 레지스터를 예약한다.
  - **ui.fx**(updateWithShader, 시뮬레이션 패스): scene include의 `__inner_txShadowArray : register(t14)`(그림자 배열)
  - **mesh.fx**(render.mesh, visor): TX_SLOT_REFLECTION_CUBEMAP t13, SHADOW_ARRAY t14, SHADOW_CLOUDS t15, DEPTH t18, PREV_FRAME t19 …
- rainfx2 시뮬레이션 패스는 newPass의 공유 텍스처 표 하나를 쓴다.
  - PERF-3(txR2Pred 추가) 후 14개(t0..t13), 한계와 정확히 같다.
  - PERF-4는 이 공유 표에 `txR2Occ`를 추가했다(시뮬레이션 패스는 쓰지도 않는다). 15번째 텍스처가 **t14 = CSP 그림자 배열 레지스터**로 들어가 이후 draw의 전역 그림자 배열 바인딩을 덮었다.
  - 그림자 / 장면 전역을 쓰는 E7(cached optics)이 카메라 변화에 따라 깜빡이고, 엉뚱한 장면 조각을 저해상도로 투영했다. E7 off면 사라지고, realvisor 쪽 변경과 무관하게 지속된 것과 일치한다.
- **검증 도구 공백:** 체크 도구는 텍스처 목록을 손으로 적어 두었고 txR2Occ가 빠져 있었다. FXC는 14개로 통과했지만 게임은 15개를 바인딩했다.
- **재현:** 도구에 레지스터 검사를 넣고 PERF-4 표(15개)를 시험하면 cells / predict / claim … 전부 `15 user textures reach reserved register t14 (ui.fx allows 14)`로 실패한다.

### 11.2 PERF-4b와 그 원복이 만든 E2 / E3 소실
- PERF-4b의 '원복'은 원래 순서(INT optics 캡처 → E7 cached 캡처)가 아니라 역순(cached → optics)을 남겼다. E7이 켜지면 두 번째 연속 복사인 INT 캡처가 실패해 E2 / E3이 사라졌다. 장치는 PERF-3의 realvisor(원래 순서)로 복원되었으므로 해소되었다.
- PERF-4b(캡처 공유)는 다시 넣지 않는다. 두 캡처의 소비자(INT 6-mip, E7 full-mip, 캡처 순서 의존)가 얽혀 있어, 공유하려면 별도 검증이 필요하다.

### 11.3 PERF-5: 재발 방지 + PERF-4 안전 재적용
- **체크 도구:**
  - 텍스처 목록을 `rainfx2/init.lua`의 newPass / drawParams 표에서 직접 읽는다(수기 목록 제거).
  - 템플릿이 예약한 가장 낮은 레지스터를 계산해 사용자 텍스처 수가 넘으면 FAILED 처리한다(ui.fx 14, mesh.fx 13). `--emit-only`에서도 검사한다.
  - occ 패스를 목록에 추가했다.
- **init.lua newPass 위에 예산 주석:** 시뮬레이션 표는 14 / 14로 꽉 찼다. 새 텍스처는 패스별 표 분리가 먼저 필요하다.
- **PERF-4 재적용(충돌 검증):**

  | 리소스 | 공유 / 종속 | 검증 |
  |---|---|---|
  | txR2Occ | visor drawParams 표에만(9 / 13) | 시뮬레이션 표는 14 유지(도구 OK) |
  | OC 캔버스(128×32 R8) | rainfx2 전용. ensureResources 생성, dispose 목록 포함 | LIFE-1 suspend / resume 재생성 |
  | passOcc | 공유 newPass 표 사용, State / Field / Big만 바인딩 | 다른 패스 텍스처 상태 변경 없음 |
  | gR2OccOn | occOk(이번 run 성공) 및 lookLab 아님 및 토글 | resume 직후 / look lab / 일시정지 전 첫 프레임은 0이라 discard 안 함. 일시정지 중에는 OC가 S와 같은 프레임 값 유지 |
  | discard 조건 | Debug, sheet on, spray scatter에서는 off | visor_depth도 같은 조건 |
  | realvisor | 변경 없음(PERF-3) | E2 / E3 / E7 경로 무변경 |

  - 'Skip empty visor tiles' 토글로 A/B 측정한다.

## 12. PERF-5 결과 (2026-11-06)
- FXC 19 OK. E2 / E3과 E7을 모두 켜면 E7 글리치가 없다(t14 충돌이 원인이었음을 확인).
- **PERF-4 occ 제거:** 'Skip empty visor tiles' on / off의 FPS가 정수 단위로 같고, draw 변동폭에도 차이가 없다. 이득이 없는 리소스 / 패스이므로 뺐다(OC 캔버스, passOcc, txR2Occ, gR2OccOn, discard, 체크 도구 항목).
  - `rainfx2/shaders/occ.hlsl`은 쓰이지 않는다. 장치에서 삭제해도 된다.
  - r2Cand의 txR2Lam 로드를 리뷰 마커에서만 하는 것은 유지한다(동작 동일).
- **E2 / E3 off + E7 on에서 글리치:**
  - 이 조합에서는 E7 cached 캡처가 post에서 첫 번째(유일한) HDR 복사가 된다.
    - GLASS-ORDER-1: INT 직전, EXT 이후
    - 이전 순서: post 시작, EXT 이전
  - E2 / E3이 켜져 있으면 INT optics 캡처가 먼저 일어나고 글리치가 없다.
  - 예전부터 있던 문제인지 판정하려고 INT 패널에 'EXT band drawn last'(GLASS-ORDER-1 이전 순서) 체크박스를 추가했다.
    - 그 상태에서도 글리치가 나면 원래부터 있던 E7 버그이다. 사라지면 GLASS-ORDER-1의 캡처 시점이 원인이다.

## 13. PERF-6 계측과 연구
- E2 / E3 off + E7 on 글리치는 EXT_LAST와 무관했다(사용자). 진단 환경에서만 발생하며, E7 개선(정면 반사, 톤, 인테리어, 주야간) 이후 재점검한다.
- 계측 추가(프로파일링 on일 때만)와 연구 계획은 `docs/RAINFX_V2_PERF_RESEARCH.md`에 있다.
- 핵심 발견: RainFX2 depth pass가 측정되지 않았다. 컬러 패스와 같은 후보 루프를 반복한다.

## 14. PERF-7 / PERF-8 (2026-11-06)
- **PERF-6 측정:** 후보 루프가 visor 두 패스 비용의 약 90 %이다. depth 패스는 colour와 같은 1.57 ms이다. 렌즈는 3 %이다.
- **PERF-7:** r2SupportMM(증명된 지지 반경)으로 기여가 없는 후보의 r2AddDrop을 건너뛴다. 결과는 동일하다. 'Tight drop support' 0 legacy | 1 on | 2 verify(빨강 = 위반)이다. 검사 도구는 `docs/tools/check_tight_support.py`이다.
- **PERF-8:** GLASS_INT_FX(와 그 뒤 항목)가 숨겨지면 optics / cachedScene 캡처와 E7 sceneReady 갱신을 생략한다.
- 근거와 증명, 충돌 검토는 `RAINFX_V2_PERF_RESEARCH.md` §5–7에 있다.

## 15. PERF-9 방울 레코드 (2026-11-06)
- **PERF-7 결과:** verify 위반이 0이었다. draw는 −14 %, depth는 −10 %였다.
- **PERF-9:** 후보의 픽셀 무관 계산(r2CandCore)을 방울당 1회 rec 패스로 옮긴다. visor는 로드 1회로 먼 후보를 배제한다.
  - 공유 코드는 `cand.hlsl`이고, 값은 `candValues` 한 곳에서 만든다. 검사 도구가 값 누락을 검사한다.
  - 상세는 PERF_RESEARCH §8–9에 있다.
