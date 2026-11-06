# RealVisor / RainFX2 최적화 연구 (PERF-6, 2026-11-06)

- **목표:** 장면 충실도(이미지 손실 없음)를 유지하면서 앱 기본 비용과 RainFX2 비용을 줄인다.
- **원칙(사용자):** 측정 근거가 먼저이다. 공유 / 종속 리소스의 충돌 지점을 검증한 뒤 반영한다(PERF-4 t14 교훈).

## 0. 지금까지의 측정
- 앱 off 87, 앱 on + FX 없음 81(≈ 0.85 ms), RainFX2 on에서 −12 ~ 13 FPS(≈ 3 ms, Heavy Rain 30 %)이다.
- **GPU(Render Stats):**
  - RainFX2 sim 0.46 ms(cells 0.14, field 0.08, merge 0.08, trail 0.04, predict 0.015)
  - RainFX2 draw 1.24–1.54 ms
  - main.smoke(glass 전체) 2.96–3.98 ms
- **측정 공백:**
  1. **RainFX2 depth pass:** glassFallback에서 post 다음에 실행되는 `rfx2:draw(…, true)`는 측정 항목이 없었다. 컬러 패스와 같은 셰이더(R2_DEPTH_ONLY)로 바이저 전체 픽셀에서 셋업, film B-spline, 34 후보 루프, 커널 union을 다시 돈다. 렌즈 장면 샘플만 빠진다. sim + draw(1.75 ms)와 FPS 손실(≈ 3 ms)의 차이 대부분일 가능성이 크다.
  2. glass 스택의 내부 분해(복사, pre, post, 캡처, E7 합성)가 없었다.
- **PERF-6 계측(프로파일링 on일 때만, off면 동일 경로):**
  - Render Stats: `RainFX2 draw/depth`, `RealVisor/Glass/fallback copy+mips`, `Glass/stack pre`, `Glass/stack post`, `Glass/capture optics`, `Glass/capture cachedScene`, `Glass/E7 composite`, `E7/bake`, `E7/probe`, `E7/native source`
  - RainFX 탭 'Visor cost probe'(진단): 0 정상, 1 = 셋업까지만, 2 = 후보 / 커널 union까지(렌즈 / 합성 없음). draw 시간 차이로 셋업 | 후보 루프 | 렌즈 + 합성 비중을 나눈다.

## 1. RainFX2: 물방울 수에 비례하는 비용의 구조
- visor 픽셀마다 5×5 셀 + 3×3 big 타일 = 34 후보를 본다(colour + depth 두 패스).
- 후보마다 r2Cand가 state / life / shape를 로드하고(텍스처 3개), 반경 / 반동 exp / 반동 이동 / 하모닉 / 창 맞춤(aspect cap, sqrt) / 모션 스트레치를 계산한다. 그다음 r2AddDrop 커널(하모닉 cos, 비대칭 apex, 스플랫 rim / finger, wobble sin 3회)이다.
- 방울 하나는 자기 창(±2 셀 ≈ 2.3 mm; 화면에서 ±60–120 px)에 드는 **수천 픽셀이 같은 r2Cand를 반복** 계산한다. 픽셀에만 의존하는 부분은 q(오프셋)와 커널 평가뿐이다. PERF-3에서 시뮬레이션의 같은 구조(75배)를 없앴던 것과 같은 성격이다.

## 2. 후보 (이미지 손실 없음, 우선순위)

| # | 안 | 기대 효과 | 충돌 / 위험 검증 |
|---|---|---|---|
| A | **depth pass 경량화 / 필요성 확인.** main.smoke 이후 depth를 읽는 draw가 있는지(car glass / 파티클) 확인. 필요하면 coverage만 계산하는 경량 경로를 쓴다(film / trail / sheet / view frame / wobble 생략, 커널의 형태항만). | 측정 depth 비용의 대부분 | depth는 '이후 투명 draw가 물 위에 그려지지 않게' 하는 계약이다. 생략하면 그 계약이 깨진다 → A/B 육안 확인 필수. 경량 경로는 컬러 패스와 같은 coverage 함수여야 한다(다르면 테두리 불일치). |
| B | **방울 렌더 레코드 사전계산(visor용 PERF-3).** 셀 패스 하나가 방울마다 r2Cand의 픽셀 독립 부분(r, f, e, sft, aMax, k, 시드, 셰이프, 모션 등)을 2–3 텍셀로 저장하고, visor는 레코드만 읽는다. | 후보당 ALU 대폭 감소. 로드 수는 비슷 | visor 텍스처 예산: 8 / 13 → 10–11 / 13(t13 예약). 같은 함수 / 같은 입력 → 비트 동일. 시뮬레이션 쪽 공유 표(14 / 14)는 건드리지 않는다(visor 표만). 레코드는 시뮬레이션 최종 S 기준이고, draw는 같은 프레임 S를 읽으므로 동기이다. |
| C | **후보 조기 배제.** 레코드에 그리기 반경(reach)을 넣고, q가 reach 밖이면 셰이프 / 라이프 로드 없이 다음 후보로 간다. | 빈 / 먼 후보 비용 감소 | B와 함께. reach 계산이 지금과 같아야 한다(잘림 방지). |
| D | **렌즈를 쿼드 균일 분기로.** 물이 없는 2×2 쿼드는 r2DropLens(장면 3 mip 샘플 ×, TIR, footprint ddx)를 건너뛴다. 조건은 쿼드 전체 any로 계산해 ddx_fine의 유효성을 지킨다. | 방울 밖 픽셀의 렌즈 비용 | rev25가 '조기 return 금지'를 둔 이유가 ddx이다 → 쿼드 균일 조건으로만. probe 2 측정으로 렌즈 비중을 먼저 확인한다. |
| E | 시뮬레이션(0.46 ms) | 낮음 | 우선순위 낮음 |

- 해상도 축소, 후보 수 축소, 근사 렌즈는 이미지 손실이 있어 제외한다.

## 3. 앱 기본 비용(FX 없음 ≈ 0.85 ms) 후보 — 측정 후 판단
- **glass fallback 복사:** dynamic::hdr 전체 해상도 RGBA16F 복사 + 전체 밉 체인을 매 프레임 한다. FX 메쉬가 모두 꺼져도 RAIN_VISOR_LAYER / SCENE_STACK이 켜져 있으면 실행된다. 소비자(glass 레이어, RainFX 소스)가 없으면 건너뛸 수 있다.
- **Native glass mask:** 전체 해상도 R32F GeometryShot. 눈-visor 상대 위치가 변할 때마다(NeckFX로 사실상 매 프레임) 다시 캡처한다.
- **E7 bake / probe / native source**(RAIN_VISOR_OPTICS_ENABLED): 캐시 키 변화 시 GeometryShot이다.
- **CPU(≈ 0.1–0.5 ms):**
  - script.update: visorLayerSceneHide(모든 에디터 setShadows / setVisible), nativeGlassState:update(setShadows 루프)
  - optics sceneReady 0.42–0.48 ms
  - UI 0.24 ms(창이 열려 있을 때만)
- 각 항목의 '소비자 없으면 생략' 조건은 소비자를 전수 확인한 뒤에 넣는다(PERF-4b 교훈: 캡처 공유 / 순서 의존).

## 4. 요청 측정 (Heavy Rain 30 %, 같은 시점, 필요한 항목만 펼침)
1. `RainFX2 draw`, `RainFX2 draw/depth`, `RainFX2 sim`
2. Visor cost probe 0 / 1 / 2에서 각 `RainFX2 draw`(colour)
3. `RealVisor/Glass/*`, `E7/*`, `Native glass mask`
4. FX 메쉬 모두 off일 때 같은 항목(기본 비용)

## 5. PERF-6 측정 결과 (사용자, Heavy Rain 30 %)

| probe | colour draw | depth | sim |
|---|---|---|---|
| 0 (정상) | 1.595 | 1.566 | 0.512 |
| 1 (셋업만) | 0.179 | 0.099 | 0.505 |
| 2 (union까지) | 1.550 | 1.487 | 0.523 |

- **후보 루프가 두 패스 모두에서 약 90 %이다.** colour 1.37 ms, depth 1.39 ms이다. 렌즈 + 합성은 0.045 ms(3 %)뿐이라 D안(렌즈 생략)은 폐기한다.
- **depth 패스는 colour와 같은 비용이다.** RainFX2 GPU 합계는 3.67 ms이다(sim 0.51 + colour 1.60 + depth 1.57). FPS 손실 ≈ 3 ms와 맞는다.
- **FX 메쉬 off 상태(기본 앱):** capture optics 0.028, capture cachedScene 0.032, E7 composite 0.003, Native glass mask 0.001 ms이다. 메쉬가 숨겨져도 캡처 2개가 실행되었다.
- **측정 주의:** Render Stats GPU 팝업을 열 때마다 FPS가 떨어지고, 창을 닫아도 복원되지 않는다(69 → 48–50). FPS 비교는 팝업을 열지 않은 새 세션에서 한다.

## 6. PERF-7 촘촘한 방울 지지 반경 (결과 동일, 두 패스 공통)

- **원인:** r2Cand의 reach는 `1.3·K·r·√A·1.35·2` ≈ 커널 반경의 3.5배이다. 그 안의 모든 픽셀이 r2AddDrop 전체를 실행한다(atan2, sin / cos, 고유값, wobble sin ×3, 하모닉 …). 그런데 실제로 h > 0인 곳은 일부이다. 나머지 픽셀에서 r2Kernel은 `h <= 0`으로 return하고 아무 값도 바꾸지 않는다. 방울 수에 비례해 비용이 오르는 원인이다.
- **해법:** `r2SupportMM`은 r2AddDrop의 변환 체인을 거꾸로 따라간 증명된 상한 B이다. |q| > B면 r2AddDrop이 P / G / RW / HW를 바꿀 수 없으므로 건너뛴다.
  - 커널 지지: |q6| < rkS·dRm. dRm ≤ (1+|a2|+|a3|)(1+finger)이고 rkS = rk0/√A이다.
  - wobble squash: |q5| ≤ |q6|/(1−A)
  - rocking: |q4| ≤ |q5| + 0.3·A·r
  - 후면 늘림(sag / slide / neck): |q3| ≤ (1+kk)|q4|
  - 종횡비 + 굽힘: |q1| ≤ A|q3| + |bend|·√A·|q3|²/rk0
  - 라멜라 중심 이동 2·sft, D-A 탭 1.5·reachMM, ×1.002 + 1e-4 여유
- **검증:**
  - `docs/tools/check_tight_support.py`는 r2AddDrop → r2Kernel을 NumPy로 옮긴 것이다. 무작위 방울 2만 개 × 3000 오프셋에서 h > 0인 최대 |q|/B는 0.993이다(< 1, 상한이 실제로 꽉 맞음). 모든 분기(shape off, 라멜라, neck, wobble 0.6, finger 1.0, impactMax 0.5–4)를 포함했다.
  - 게임 안에서는 'Tight drop support' 2(verify)를 쓴다. 건너뛸 후보를 그대로 그리고, 그 후보가 실제로 기여한 픽셀을 빨간색으로 표시한다. 빨간 픽셀이 0이어야 한다.
- **기대 효과:** r2AddDrop을 실행하는 면적이 고정 방울 기준 legacy의 13–20 %, 미끄러지는 방울 기준 40 %로 줄어든다.
- **충돌 검토:**
  - 새 텍스처 / 패스 / 순서 변경이 없다. visor 셰이더 내부의 순수 ALU 조건이다.
  - S6c / R2b 마커는 건너뛰기 전에 계산한다(기존과 같다).
  - 단일 r2AddDrop 호출 지점을 유지한다(rev48-R7a FXC 제약).
  - depth 변형에서는 verify 표시가 컴파일되지 않는다.

## 7. PERF-8 기본 앱: 숨겨진 소비자의 작업 제거

| 작업 | 소비자(전수 확인) | 생략 조건 |
|---|---|---|
| capture optics(6 mips) | sov.src: post의 kind-3(GLASS_INT_FX)과 그 뒤 항목(EXT_LAST일 때 EXT) | 그중 보이는 항목이 없을 때 |
| capture cachedScene(full mips) | E7 composite(cachedOptics:draw)만 | GLASS_INT_FX가 숨겨졌을 때 |
| E7 bake / probe / native source(sceneReady, CPU ≈ 0.4 ms) | optics:draw만 | draw의 조기 return 조건과 똑같을 때(e1SourceEditor, targetMesh 1개, Visible) |

- **'보인다'의 판정:** visorLayerDrawItem이 그리기 전에 쓰는 검사와 같다(editor, targetMesh, visible).
- **캡처를 생략할 때:** `vl.opticsReady = true`로 둔다. 기존에도 숨겨진 항목은 drawReady를 바꾸지 않았으므로 postViewKey 메모 동작이 같다. cachedScene 캔버스는 해제한다(다시 보이면 같은 프레임에 재생성된다).
- **E7 갱신을 생략할 때:** 아무것도 해제하지 않는다. 다시 보이면 같은 프레임의 sceneReady가 draw보다 먼저 갱신하므로 이전 값이 남지 않는다.
- **보류:**
  - fallback copy+mips: 소비자가 glass 항목, RainFX2 source / depth, E1로 넓다.
  - nativeCapturePrepare(opticsProbe / opticsSource): 준비 시점이 E7 갱신과 같은 프레임인지 확인이 필요하다.

## 8. PERF-7 결과 (사용자, Heavy Rain, intensity 편차 있음)
- **verify 모드:** Heavy Rain과 Light Drizzle 모두 빨간 픽셀이 0이었다. 결과가 동일함을 확인했다.
- **비용:** Tight 0 → 1에서 colour draw는 2.128 → 1.835 ms(−14 %), depth는 1.747 → 1.565 ms(−10 %)이다.
  - 생략된 r2AddDrop은 루프 비용의 일부였다. 남은 대부분은 후보마다 픽셀과 무관한 r2Cand 작업이다(로드 3–4 + exp / pow / sqrt를 포함한 ALU 약 60).
- **FPS:**

  | 상태 | FPS |
  |---|---|
  | FX 메쉬 off | 97 |
  | + RainFX2 | 74 (≈ 3.2 ms) |
  | 전체 on | 69 |

- **GLASS_INT_FX on / off(PERF-8):** E7과 E2 / E3이 즉시 복귀했다.

## 9. PERF-9 방울 레코드 (visor용 PERF-3)
- **구조:** r2Cand를 `r2CandCore`(픽셀 무관)와 오프셋 / reach 판정으로 나눴다. 공유 코드 `cand.hlsl`을 visor와 rec가 함께 쓴다.
- **rec.hlsl:** 프레임마다 simulate 끝(그려지는 모든 출구: 정상, paused, look lab)에서 방울당 1회 실행한다. REC는 6 × cellsU × cellsV RGBA32F(6.3 MB)이다.
  - [0] 중심(cells), ±(rLeg+1)(− = big-tile 방울, 0 = 빈 셀), 조기 배제 반경 w
  - [1] r, k, f, fx  [2] sh  [3] m, seed, ch  [4] e, sft, aMax, imp  [5] nk
- **w의 정의:** max(r2SupportCore(A = wobbleAmp 상한), S6c / R2b 마커 반경)이다. B는 A에 대해 단조 증가하므로 w ≥ 픽셀별 B이다. w 밖의 후보는 union과 마커 어느 쪽도 바꾸지 않으므로 **로드 1회 후 건너뛴다.** 안쪽 후보만 나머지 5 텍셀을 읽는다.
- **결과 동일성:**
  - 같은 함수, 같은 텍스처(draw는 recS / recLM이 지금 바인딩과 같을 때만 사용, 아니면 픽셀별 경로), 같은 값을 쓴다.
  - 값은 `candValues(self, v)` 한 곳에서 만든다. drawParams와 recUpdate가 둘 다 호출한다.
  - 차이는 rLeg 인코딩의 ULP(legacy reach 경계)뿐이다. 그리고 sceneReady와 draw 사이에 UI 슬라이더가 바뀐 그 1프레임이다.
- **충돌 검토:**
  - visor 텍스처는 9 / 13이다. rec는 자기 표 3개(State, Lam, Big)를 쓴다. 공유 시뮬레이션 표(14 / 14)는 그대로다.
  - REC는 simulate에서만 쓰고 visor에서만 읽는다. dispose 목록에 들어 있고 recValid / recS / passRec도 초기화한다.
  - verify(2)는 조기 배제 후보도 전부 읽어 그린다 → w와 B를 둘 다 검사한다.
- **검사 도구 추가(PERF-9):** `check_rainfx2_shaders.py`가 rec / visor 패스에서 셰이더가 읽는 gR2 값이 init.lua(candValues, drawParams, draw)에서 설정되는지 확인한다. 설정되지 않은 값은 게임에서 컴파일 오류 없이 0이 되는 공유 리소스 위험이다. 일부러 넣은 오류(gR2FooTest)를 검출하는 것을 확인했다.
- **UI:** RainFX 탭에 'Drop records' 체크박스를 둔다(off = PERF-7 픽셀별 경로).

## 10. PERF-9 결과 (사용자, Heavy Rain)

| | rec | colour draw | depth |
|---|---|---|---|
| Drop records off (PERF-7) | – | 1.836 | 1.496 |
| on | 0.034 | **1.203** | **1.095** |
| PERF-6 기준(Tight 0) | – | 2.128 | 1.747 |

- verify 모드로 2분 주행했고 위반이 0이었다.
- **PERF-6 대비 개선:** colour −43 %, depth −37 %, 합계 약 1.6 ms이다(rec 0.034 ms 포함).
- **기본 앱:** RealVisor 제거 94–95, 이전 세션 93–97 변동, FX off 97로 측정 오차 범위 안이다. PERF-8 이후 FX off 상태의 앱 고정비는 측정되지 않는 수준이다.
- **FXC X3556**(rec의 int 나눗셈)은 uint로 수정했다.

## 11. PERF-10 셀별 후보 마스크
- **근거:** PERF-9 이후에도 visor 픽셀마다 레코드 34개(5×5 셀 + 3×3 big 타일)를 로드한다. 대부분은 빈 셀이거나 조기 배제 반경 w 밖이다. 레코드 덕분에 후보당 비용은 로드 1회 + 비교로 작아졌지만, 34회 × 두 패스가 바닥 비용으로 남는다.
- **msk.hlsl(셀당 1회):**
  - visor 루프와 같은 인덱스 ci(0–24 셀, 25–33 big)로 후보를 찾는다.
  - 레코드 중심과 셀 사각형 [c0, c0+1] 사이 거리 d를 계산한다.
  - d ≤ min(w·1.002, rLeg)·1.001 + 1e-4 mm이면 비트를 켠다.
  - 출력은 RG32F이다. x = 비트 0–16, y = 비트 17–33(정수값 float, 정확함).
- **동일성 근거:**
  - 셀 안 픽셀의 |q|는 사각형 거리 d보다 작을 수 없다. 꺼진 비트의 후보는 r2CandRec에서 반드시 reach 밖이거나 early로 배제된다. 그래서 켜진 비트만 순회해도 결과가 같다.
  - 여유(×1.001 + 1e-4)는 후보를 더할 뿐이다. 더해진 후보는 픽셀별 판정을 그대로 거친다.
- **적용 조건:** 레코드 사용, tight 1, D-A 확대 없음(reachMM 0, `multi` 아님), c0가 범위 안일 때. 하나라도 아니면 34개 전체를 순회한다.
- **verify(2):** 34개를 모두 돌린다. 처리된(early가 아닌) 후보가 마스크에 없으면 빨강으로 표시한다. 마스크도 함께 검사된다.
- **충돌 검토:**
  - visor 텍스처는 10 / 13이다. msk는 자기 표 2개(Rec, Big)를 쓴다.
  - 값은 candValues(Cells, CellSizeMM, BigOn)에서 온다. 검사 도구가 값 누락을 검사한다.
  - MSK는 recUpdate에서만 쓰고(REC 직후, 같은 프레임) visor에서만 읽는다. mskValid가 recValid에 종속되고, dispose 목록에도 들어 있다.
  - 단일 r2AddDrop 호출 지점을 유지한다. 루프만 for에서 비트 순회 while로 바꿨다.
- **UI:** 'Candidate mask' 체크박스.

## 12. PERF-10 결과 (사용자, Heavy Rain)

| 단계 | colour draw | depth | 추가 패스 |
|---|---|---|---|
| PERF-6 기준 | 2.128 | 1.747 | – |
| PERF-7 | 1.836 | 1.496 | – |
| PERF-9 | 1.203 | 1.095 | rec 0.034 |
| PERF-10 | **0.567** | **0.368** | + msk 0.025 |

- verify 위반은 0이었다. 마스크 off일 때(같은 세션) draw 1.410, depth 1.261 ms였다.
- **visor 두 패스 합계:** 3.875 → 0.935 ms(−76 %, 약 2.9 ms 확보)이다. 이미지 손실이 없다(증명 + verify).
- **남은 RainFX2 GPU:** sim 0.58 + draw 0.57 + depth 0.37 + rec / msk 0.06 ≈ 1.6 ms이다. 이제 sim이 가장 크다.
- **다음 후보(측정 후):**
  - sim / cells(PERF-3 이후 0.14)
  - field
  - merge
  - draw / source(0.5배 refraction source + mips)
  - CPU: sim 제출 0.64 ms(Lua)

## 13. 측정(사용자)과 PERF-11 CPU 계측
- **FPS:** 같은 조건(정지)에서 69 → 75–77이다.
- **sim GPU(ms):**

  | cells | field | merge | trail | predict | claim | big |
  |---|---|---|---|---|---|---|
  | 0.145 | 0.089 | 0.085 | 0.043 | 0.017 | 0.015 | 0.014 |

  - 합계 0.41, sim 전체 0.58이다(나머지: lam / sizes / metrics / sheet / nuc / bead / seed / rec / msk).
- **draw / source:** 0.035–0.052 ms이다.
- **관찰:** sim 패스마다 CPU가 약 0.055–0.07 ms이다(Render Stats). 패스 수(substep 포함) × 이 값이 sim CPU 0.64 ms이다. GPU 패스 하나보다 CPU 제출이 더 비싸다.
  - 후보 원인 1: sceneValues가 패스마다 약 170개 값을 다시 쓴다(16개 문자열 생성, fragLaw 포함).
  - 후보 원인 2: CSP가 updateWithShader마다 값 표를 마샬링한다.
- **PERF-11(계측 + 무해한 수정):**
  - 'gR2DQ'..i 이름을 한 번만 만든다(sceneValues, drawParams). 같은 키, 같은 값이다.
  - 프로파일러 on일 때 RV_PROF 표에 두 항목을 넣는다.
    - `RainFX2 sim Lua: sceneValues`: 프레임당 Lua 시간
    - `RainFX2 sim Lua: pass submit (N calls)`: updateWithShader 호출 시간. render.measure 비용 포함, 대부분 CSP 마샬링과 제출이다.
  - 두 값의 비율로 다음 조치를 정한다.
    - sceneValues가 크면 상수 / 프레임 값을 분리한다.
    - submit이 크면 패스 수나 값 수를 줄인다.

## 14. PERF-11 결과 → PERF-12 lean pass values
- **CPU 표(사용자, 프로파일러 on, 프레임당 EMA, 콜백 25개 합 2.54 ms):**

  | 항목 | ms |
  |---|---|
  | RV sceneReady L14967(RainFX2 sim 전체) | 0.658 |
  | RainFX2 sim Lua: pass submit (10 calls) | 0.499 |
  | RV sceneReady L14573(E7 optics bake / probe / source) | 0.432 |
  | RV main.smoke L14981(glassFallback: 복사, 스택, RainFX2 draw) | 0.426 |
  | windowMain UI | 0.258 |
  | RainFX2 sim Lua: sceneValues | 0.034 |

- **판단:** sceneValues(Lua 값 계산)는 무시할 수준이다. sim CPU의 3/4은 updateWithShader 제출이다(호출당 약 0.05 ms, render.measure 비용 포함).
  - 패스마다 sceneValues 전체(약 190개 항목, gR2DQ 16개 포함)가 값 표에 들어 있다. CSP는 호출마다 표의 모든 항목을 cbuffer로 옮긴다.
- **PERF-12:**
  - newPass가 셰이더 소스의 gR2 이름을 한 번 스캔한다. 그 표에는 그 이름만 복사한다(sceneValuesImpl → 공유 SV_FULL → 이름 목록).
  - sceneValues가 설정하지 않는 이름은 건드리지 않는다. seed / dt 덮어쓰기 동작은 전과 같다.
  - 셰이더가 읽는 값과 그 값의 내용은 동일하다.
- **충돌 검토:**
  - 이름 목록은 셰이더 소스 전체(주석 포함)에서 뽑으므로 상위집합이다. 누락이 생길 수 없다.
  - 덮어쓰기 값(gR2Dt, gR2SheetDt, seed의 gR2Frame / SeedMode / Lab*)은 호출자가 run 직전에 매번 다시 쓴다.
  - 토글하면 모든 패스의 값 표를 새로 만든다. 다른 모드에서 남은 키가 없다. 셰이더 재컴파일 동안 sim이 몇 프레임 'compiling'일 수 있다.
  - visor / rec / msk 값 표는 대상이 아니다(drawParams / candValues).
- **UI:** 'Lean pass values' 체크박스. on / off로 `pass submit` CPU를 비교한다.
- **다음 CPU 후보:**
  - E7 sceneReady 0.43 ms: updateBake의 cacheKey 문자열을 매 프레임 만든다.
  - glassFallback 0.43 ms

## 15. PERF-12 결과(효과 없음 → 되돌림)와 PERF-13 CPU 분해
- **PERF-12 측정:** pass submit은 on 0.310, off 0.325 ms였다. sim 전체는 0.517 / 0.473 ms(EMA 변동 범위)였다. 값 개수는 제출 비용을 좌우하지 않는다.
  - CSP 제출은 호출당 고정 비용이다(약 0.03 ms, render.measure 포함).
  - 원칙(이득이 없는 구현은 남기지 않는다, occ와 같다)에 따라 init.lua를 PERF-11 상태로 되돌렸다. DQ 이름 캐시와 CPU 계측은 유지한다.
  - 이미지 이상은 없었다(사용자).
- **남은 CPU 상위:**
  - E7 sceneReady 0.42 ms
  - glassFallback(main.smoke) 0.40 ms
  - UI 0.26 ms(창 열림 시)
- **PERF-13 계측(프로파일러 on만):**
  - `rainDynamicSceneCopyState.measure`가 각 구간의 CPU를 프로파일 표에 `RV <key> (CPU)`로 넣는다.
    - glass: fallback copy+mips, stack pre / post, capture optics / cachedScene, E7 composite, RainFX2 draw/depth
    - E7: E7/bake / probe / native source, Native glass mask
  - visor_optics updateBake 안을 나눴다: `E7/bake: validate`, `optics.verify read`(매 프레임 디스크 파일 open / read), `cacheKey`(벡터 약 50개 문자열화 + 머티리얼 속성 조회, 매 프레임).
  - 중첩 구간은 바깥과 안쪽에 모두 나오므로 표의 total은 실제보다 크다.

## 16. PERF-13 결과 → PERF-14 (E7 bake CPU)
- **측정(프로파일러 on):**

  | 항목 | ms / frame |
  |---|---|
  | E7/bake | 0.420 |
  | └ optics.verify read(매 프레임 디스크 open / read) | **0.292** |
  | └ cacheKey | 0.120 |
  | Glass/stack post | 0.189 |
  | └ E7 composite | 0.099 |
  | Glass/stack pre | 0.073 |
  | RainFX2 draw/depth | 0.054 |
  | Native glass mask | 0.035 |
  | E7/probe | 0.021 |
  | fallback copy, captures | < 0.01 |

- **PERF-14(visor_optics.lua):**
  - optics.verify는 최대 2초마다 읽는다(해시 캐시). 자산 재빌드 / 삭제는 다음 프레임 대신 2초 안에 감지된다. 그 밖의 동작은 같다.
  - cacheKey는 키 문자열이 비트 동일하다.
    - 무효화 메시지용 labels 표는 키가 바뀐 프레임에만 만든다(그 프레임은 cacheKey를 한 번 더 호출한다).
    - transformKey의 점 4개는 상수로 만들어 둔다(매 호출 vec3 할당 44개 제거).
    - 머티리얼 속성 조회는 클로저 없이 pcall(ref.getMaterialPropertyValue) 형태로 바꿨다(같은 결과, 같은 실패 처리).
- **충돌 검토:** cacheKey의 호출자는 updateBake 한 곳이다. labels는 키 변경 분기 안에서만 쓰인다. verifyHash는 이 모듈 안에서만 쓴다.
- **기대 효과:** CPU 약 0.29 ms에 cacheKey 일부를 더한 만큼 줄어든다.
