# CSP preview728 dwrite.dll 역공학 2차 — 최속·합리적 화질 RainFX 구현안

2026-10-25. 대상: `lights-patch-v0.3.0-preview728/dwrite.dll`
(SHA256 `027fe86e…bf56a9`, 1차 분석 [CSP728_RAINFX_STATIC_ANALYSIS](CSP728_RAINFX_STATIC_ANALYSIS.md)과 동일 파일).
DLL은 수정·실행하지 않았다. PE/문자열/내장 ZIP/DXBC/x64 정적 분석과 오프라인 프로토타입만 수행했다.
**게임 내 구현·성능 측정은 아직 없다.** 아래 ms 값은 모두 추정치이며 `render.measure`로 확인해야 한다.

## 0. 결론

**있다.** 권장안은 **"GPU 상주 셀 입자(cell-gather) + 저해상 표면장 + 디포커스 광학 1패스"** 다.

- 방울 상태를 텍스처 셀(1셀=최대 1방울)에 저장하고, 픽셀 셰이더가 주변 셀을 **gather**해서
  이동·합체를 처리한다. compute 없이 CSP의 GPU 입자 방식(`pfxWindscreen_cs_*`)과 같은 일을 한다.
- 프레임당: 오프스크린 소형 패스 3종(셀 시뮬은 서브스텝 2–4회) + 밉 생성 1 + 기존 바이저 메시 셰이더 1.
  **readback 0, 정점 업로드 0, 방울 단위 Lua 처리 0.** CPU는 날씨→파라미터 변환(수십 개 값)만 한다.
- 예상 비용(추정): GPU 0.25–0.45 ms @1440p, CPU < 0.1 ms, VRAM < 4 MiB.
- 근거: CSP 자신의 windscreen/screen-drops/helmet 구현이 모두 **GPU 입자 + UV/화면 공간 저비트 맵 +
  밉 LOD 블러 굴절** 구조다(§1). Lua에는 compute·UAV·커스텀 VS가 없으므로 같은 구조를 픽셀 셰이더만으로
  옮기는 형태가 셀-gather다.
- 이전 제안 [RAINFX_CSP_REDESIGN](RAINFX_CSP_REDESIGN.md)(CPU 방울 + `alterVertices` 배치)과 비교하면
  CPU 0.6–1.0 ms 목표와 nominal 41 MiB/s 정점 업로드가 없어지고, 합체(coalescence)가 gather 과정에서 자동으로 생긴다.

## 1. 이번에 확인한 사실 (증거)

| # | 사실 | 근거 위치 |
|---|---|---|
|1|windscreen RainFX 프레임 갱신은 한 함수에서 순서대로 실행된다: `Prepare normals → Prepare wipers → Prepare splashes → Update drops → Draw base drops mask → Finalize base → Finalize blurred → Finalize traces`|함수 RVA 0xDE89B0–0xDEA035의 GPU 프로파일러 라벨 LEA|
|2|방울은 **compute 입자**다. `pfxWindscreen_cs_emit`(176 instr), `_cs_simulate`(408 instr, 256 thread/group, 48 B/입자, alive/dead 리스트 u1/u3, raw 카운터 u4). 힘·흐름 맵(t7, rg=2x−1), 물 맵 mip 2/3/5(기존 물로 끌려가 길을 따라감), 확률적 고착(cb8[7].w)을 쓴다|`custom/pfxWindscreen_cs_simulate.fxo` 자체 디스어셈블|
|3|맵 해상도/형식(품질 배율 적용 전 기본값): water 1/2 2048² RGBA8_SNORM 핑퐁, traces 1/2/blurred 1024² RGBA8, final 2048² RGBA8, water blurred 256² R8, normals X/Y·position 512² RGBA16F, occlusion 512² RGBA8, wipers 1024² RGBA8, splashes 512² RGBA8. **대부분 8비트**|초기화 함수 0xDE4CC0–0xDE6587의 텍스처 descriptor 즉치값|
|4|**Screen drops**(`rain_screen_drops_impl`): `pfxRainScreen_cs_emit`은 rain occlusion 그림자 배열 4-tap PCF와 차량 실내 볼륨으로 막힘을 판정한다. **DISTANT**(콕핏 기본값): 방울마다 속도로 늘인 quad를 SV_VertexID로 structured buffer에서 끌어와 그리고, PS가 장면을 반전 렌즈 오프셋 + bias 2로 샘플한다. 전체 화면 패스가 없다. **CLOSE**: R8 물 RT에 원반을 그린 뒤 fade(min 0.8, −k·dt), combine(<1/600이면 조기 종료, 16-tap 미분 gradient → 오프셋×3.5, 장면 LOD = water×6)|`pfxRainScreen_*`, `accRainScreen_fade/combine_ps`|
|5|**CSP 자체 헬멧 바이저 비**: `ac_ext_helmet`/`NECK_FX_HELMET`/`accNeckHelmet_ps_0` = 헬멧 RT 16-tap 원반 블러, 비가 켜지면 roll 회전한 rain view(t1, premultiplied)로 장면(t2)을 오프셋 샘플하고 LOD를 그 텍스처에서 받아 알파 합성. `get_helmet_rain_view()`|`accNeckHelmet_ps_0` 디스어셈블, RTTI 문자열|
|6|CSP 굴절 유리(`main_fx/smGlass_phel_ps`)는 t19를 `lod` + roughness LOD로 `sample_l`하고 채널별 색분산 오프셋을 쓴다 → **t19에는 mip이 있다**. Lua 템플릿은 t19를 `txPreviousFrame`(main pass 전용)으로 노출한다|`main_fx_smGlass` asm 1580–1593행, `shader-tpl/include_textures.fx`|
|7|Lua 셰이더는 **PS만** 바꿀 수 있다(mesh/fullscreen/quad/ui 템플릿의 VS 고정). 텍스처는 최대 32개. compute/UAV/instancing이 없다. 템플릿 출력은 항상 `float4 SV_TARGET`이므로 **UInt 렌더타깃은 쓰면 안 된다**(Float/UNorm 형식만). ExtraCanvas는 mip·`mipsUpdate()`·`:mip(i)`·RGBA32F/RGBA16F/RGBA16_UNorm을 지원한다|`internal/shader-tpl/*.fx`, `lua-sdk/ac_apps/lib.lua`|
|8|CSP 내부 rain 텍스처를 Lua에서 읽는 이름은 없다(`dynamic::screen/hdr/depth/noise`, `carN::…`뿐). 날씨 입력은 `rainIntensity/rainWetness/rainWater`, `wiper*`, `bodyWetness`, `SceneTweaks.stationaryRainDrops`|lib.lua 5376, 7643, 16746, 18223행|
|9|**rainIntensity → mm/h = ×100.** CSP 디버그 UI 분류: <0.1 none, <0.25 trace, <1 drizzle, <2.5 light, <10 moderate, <50 heavy, ≥50 violent (단위 mm/h)|함수 0x1807CA830, .rdata 상수 100.0/0.1/0.25/2.5/10/50|
|10|`rain_fx.ini [SCREEN_DROPS] STYLE_COCKPIT=DISTANT`가 기본값이다 → **콕핏에서 CSP가 이미 화면 방울을 그리므로 우리 바이저 방울과 겹친다**|preview728 `extension/config/rain_fx.ini`|
|11|`windscreen_fx/` 셰이더군은 반사·굴절 캡처용 **단순화된 재질 변형**이다(AO t17 없음, 명령 수 감소). 차량 유리 재질에서 rain final 맵을 소비하는 최종 경로는 이번에 끝까지 추적하지 않았다(미확인)|`windscreen_fx` vs `main_fx` smGlass 비교|

1차 분석의 move(`uv+0.002·v` 이류)/velocity(21-tap 평활)/finalize(LOD1.5 gradient) 해석은 그대로 유효하다.
CSP의 windscreen은 **입자(정확한 방울 머리) + 텍스처 이류·감쇠(흔적·물막)** 두 층으로 나뉜다.

## 2. 대안 비교

|안|요약|판정|
|---|---|---|
|A0 CSP 내장 그대로(screen drops / Neck FX helmet)|추가 비용 0, 그러나 흔적·haze·바이저 광학을 제어할 수 없음|기준선. 우리 효과를 켤 때는 끄는 대상|
|A1 바이저를 차량 windscreen으로 편입|Lua로 스폰한 kn5는 차량 메시 집합이 아니다. 차량마다 config가 필요하고, CSP는 position/normals를 한 번 bake(`Prepare normals`)하므로 G-force로 움직이는 바이저와 맞지 않는다|비권장|
|A2 CPU 방울 + 정점 배치(이전 제안)|디버깅은 쉽다. CPU 0.6–1 ms + 업로드, 셀 검색 필요|대안|
|**A3 GPU 셀-gather (권장)**|CSP 입자와 같은 성질을 PS만으로 구현. 합체 자동, 경로·닦임 일관|**채택**|
|A4 순수 절차적 방울(Heartfelt류)|가장 빠르다. 경로·닦임·누적이 상태와 무관|미세 디테일 보조로만|

## 3. 권장 구조

### 3.1 자원 (합계 < 4 MiB)

|이름|해상도/형식|내용|
|---|---|---|
|S0/S1 셀 상태|128×64 **RGBA32F** 핑퐁 (바이저 가시 영역 약 0.12×0.06 m, 셀 ≈0.94 mm)|x,y = 셀 내 위치[0,1), z = 체적(m³), w = 나이+상태 플래그. **속도는 저장하지 않는다**: 종단속도 모델이라 매 스텝 힘에서 다시 계산(메모리리스, 결정적)|
|G 표면 bake|128×64 RGBA16F, 로드 때 1회|바이저 로컬 법선(xyz), 유효 마스크/노출. 기존 surface metric bake 재사용|
|F0/F1 표면장|256×128 **RGBA16_UNorm** 핑퐁|R 흔적 T, G 미세 haze M, B 수막 W, A 최근 충돌/닦임 타이머. 느린 감쇠에 8비트는 거칠어서 16비트|
|O 광학 아틀라스|512×256 RGBA8_UNorm + mips|nx, ny, coverage, thickness. 디포커스 때문에 4096급 해상도가 필요 없다|

### 3.2 패스 (모두 `ExtraCanvas:updateWithShader`, 프레임당 1회. VR 양안·미러에서 반복하지 않음)

- **P1 셀 시뮬** ×N 서브스텝 (N = clamp(ceil(v_max·dt / (2·cell)), 1, 4), gather 반경 R=2 → 25 tap):
  1. *birth*: 셀별 해시 RNG로 포아송 충돌 판정. 크기는 DSD 역CDF로 샘플. 이미 방울이 있으면 체적 합산(합체).
  2. *힘*: F = m·(g_t + a_car,t) + ½ρC_dπr²|u_t|u_t. 고착 임계 F_pin = γ·2r·Δcosθ·noise(cell)
     (정적 코팅 불균일 텍스처 → 지그재그 경로). |F|>F_pin이면 v = (F−F_pin)/(c·r).
  3. *흔적 손실/증발*: 이동 거리에 비례해 체적 감소. 반경이 임계 미만이면 방울을 제거하고 흔적·미세 물로 넘긴다.
  4. *예측*: p' = p + v·dt / cell. **destination 셀이 주변 25셀의 예측을 같은 코드로 다시 계산해서**
     자기 셀로 들어오는 것을 체적 가중 평균으로 합친다. 같은 셀로 들어오면 합체가 된다. 바깥으로 나가면 소멸한다.
  5. 셀 한계를 넘는 고속 방울(바람에 날리는 방울)은 *streak*로 바꾼다: 제거하고 F의 T에 경로 시작부를 기록한 뒤
     P2의 이류가 흐름 방향으로 늘인다. 실제로도 고속에서는 바이저 방울이 몇 프레임 만에 날아간다.
- **P2 표면장**(256×128): 3×3 셀의 이번 스텝 이동 구간(capsule)과 거리 계산 → M 제거·T 기록.
  M += 미세 공급·dt·(1−M), M *= exp(−dt·(증발 + 전단·노출)), T/W는 힘 맵 방향 semi-Lagrangian 1-tap 이류 후 감쇠.
- **P3 광학**(512×256): 3×3 셀 방울의 해석적 구면 캡(높이·법선을 해석적으로, ddx 불필요) + T/W의
  저주파 법선(2-phase 이류 노이즈, W에 비례). 이어서 `mipsUpdate()`.
- **P4 바이저 합성**(기존 바이저 `render.mesh` PS에 추가): O를 디포커스 LOD로 1 tap, F 1 tap, 장면 2–3 tap.
  - 굴절: uv_scene += n.xy·k (해상도 독립 px 단위로 제한), 방울은 장면을 mip+1로 샘플(CSP DISTANT도 bias 2).
  - haze: 장면 LOD = f(M) (CSP combine의 LOD=water×6과 같은 방식) + 산란 베일(ambient/fog 색 쪽으로 보간). 전체 화면 blur는 쓰지 않는다.
  - 림/스펙 글린트: `gLightDirection`·헤드라이트로 아주 약하게.
  - dry 픽셀(coverage=0, M≈0)은 조기 반환.

### 3.3 비용 추정(검증 필요)

|패스|픽셀|tap/픽셀|추정|
|---|---|---|---|
|P1 ×4|8k|25 (+G,노이즈)|< 0.03 ms|
|P2|32k|~12|< 0.02 ms|
|P3 + mips|131k|9|~0.03 ms|
|P4|화면의 바이저 픽셀(1440p 최대 ≈3.7M)|~6|0.15–0.35 ms|
|CPU|—|API 호출 ~6, 파라미터 테이블 재사용(`directValuesExchange`)|< 0.1 ms|

### 3.4 장면 색 소스

1순위 **`txPreviousFrame`(t19)**: CSP 유리가 이미 쓰는 mip 있는 굴절 소스이므로 별도 복사가 필요 없다.
1프레임 지연은 Lua에서 이전 프레임 view·proj를 값으로 넘겨 **회전만 재투영**해서 보정한다(배경이 멀다고 가정).
**검증 1줄**: `txPreviousFrame.GetDimensions(0, w, h, levels)`로 render.mesh 문맥에서 mip 수를 확인한다.
mip이 없으면 2순위로 현재의 `dynamic::hdr` + 반해상도 1회 복사 + mips를 바이저 효과 전체가 공유한다.

## 4. CSP 날씨 → 모델 매핑 (프리셋 없이 연속 입력)

|입력|식|화면 결과|
|---|---|---|
|강수율 R|R[mm/h] = rainIntensity × 100 (§1-9)|—|
|방울 크기 분포|Marshall–Palmer: Λ = 4.1·R^−0.21 mm⁻¹, 평균 D = 1/Λ (R=2→0.28 mm, 10→0.39, 50→0.55)|강할수록 큰 방울 비율 증가|
|체적 플럭스|q = (R/3.6e6)/v_t · max(0, −v̂_rel·n)·|v_rel| · exposure. v_t≈6 m/s, v_rel = 차량속도 − 바람 − 낙하|고속이면 같은 R에서도 충돌이 약 v/v_t배(B)|
|충돌률|λ = q / E[V_drop]|C 희소, B·A 다수|
|미세 분율|충돌 Weber 수 ∝ ρv²D/σ가 높을수록 비산 → M 공급 증가|고속 중간비의 haze(B)|
|제거|전단 ∝ u_t²·노출(G), 방울 경로 수거, 증발 ∝ (1−humidity)|고속에서 노출부가 건조하게 닦임, 정체부(상단)는 haze 유지|
|스프레이|Σ(앞차) rainWater·f(속도)·g(거리, 횡오프셋), 상한 있음. 앞차가 없으면 0|A의 대량 유입. 공중 물보라 자체는 CSP 파티클 담당|
|마름/잔류|rainWetness는 비가 그친 뒤 잔류 시간 스케일로만 사용(바이저 물량 하한으로 쓰지 않음)|비 그친 뒤 C 쪽으로 회복|
|고착|F_pin vs F_drive (r에 비례 vs r³·u²)|저속은 작은 방울이 붙어 있고 큰 방울만 이동(C)|
|수막 W|충돌률·T·M이 모두 높을 때만 성장, 흐름 이류 후 배수|A의 저주파 강한 왜곡|
|노출|오픈 콕핏이 아니면 0 (사용자 토글 + 차종 휴리스틱)|폐쇄 콕핏에서 바이저 비가 생기지 않음|

## 5. CSP 렌더 패스와의 공존

- P1–P3은 프레임당 1회(프레임 카운터 가드). VR·미러·추가 뷰에서는 P4만 뷰별로 실행한다.
- P4는 기존 바이저 메시 경로(`main.track.transparent`)에 통합하고, 새 전체 화면 패스는 만들지 않는다.
- RealVisor RainFX가 켜져 있으면 **CSP `STYLE_COCKPIT=NONE` 권장**(이중 방울 방지), Neck FX helmet 비활성 권장.
  Lua에 이 설정을 바꾸는 API는 없다 → 앱 UI에 안내를 표시한다.
- CSP 월드 비/스플래시/스프레이 파티클은 그대로 두고 복제하지 않는다.

## 6. 화질을 싸게 얻는 핵심

1. **디포커스**: 바이저는 눈에서 3–5 cm, 동공 3–6 mm → 흐림각 ≈ 동공/거리 = 4–10°. 사람 눈 기준 방울은 흐린 렌즈 덩어리다.
   카메라(영상)처럼 보이게 하려면 흐림을 줄인다 → 슬라이더 하나. 저해상 O를 mip LOD로 샘플하는 것만으로 처리된다.
2. 방울 렌즈는 **반전 오프셋 + mip+1**, haze는 **LOD 블러 + 베일**. CSP가 쓰는 두 기법 그대로다.
3. 모든 효과가 상태(S/F)에서 나오므로 popping이 없고, C→B→A가 같은 계수로 연속 전환된다.

## 7. 오프라인 프로토타입 검증

`docs/prototypes/cellrain/cellrain.py`(numpy): GPU 패스와 1:1로 대응하는 셀-gather(3×3 버전) 구현.
배경은 사용자 영상 C의 한 프레임이다. 10 s 시뮬 결과:

|장면 입력|방울|이동 중|평균 M|
|---|---|---|---|
|C: R=2 mm/h, 25 m/s|96|0|0.01|
|B: R=8, 65 m/s, 약한 스프레이|566|99|0.17 (상단 haze 띠)|
|A: R=40, 60 m/s, 스프레이|882|219|0.44|

- gather 단계의 **체적 보존 오차 0**(가장자리 이탈 제외, 출생·손실 끈 120 스텝 검사).
- 결과 이미지: `docs/prototypes/cellrain/cellrain_regimes.png`(위부터 원본/C/B/A).
- 한계: 수막 W·흐름 노이즈·스프레이 거동 미구현, 계수는 추정값, 정적 배경, **게임 검증 아님**.
  A의 큰 저주파 왜곡은 W 구현 후에 다시 평가해야 한다.

## 8. 구현 순서와 합격 기준

1. P1+P3+P4, 고정 입력 → 방울이 보이고 안정적인지, `render.measure` 수치 확인 (예상 2–4 h).
2. P2 + 날씨 매핑 → C/B.
3. W + 스프레이 추정 → A.
4. 설정·VR·CSP 이중 방울 안내 정리.

합격 기준: GPU ≤ 0.5 ms @1440p, CPU ≤ 0.1 ms, readback 0, 같은 계수로 C→B→A 연속.

## 9. 미확인·위험

- `txPreviousFrame`이 render.mesh 문맥에서 mip을 갖는지, 현재 프레임 opaque 복사인지 이전 프레임인지(§3.4 검증 1줄).
- 셀당 1방울 → 고밀도(A)에서 조기 합체. 셀 크기를 전형적 방울 지름과 비슷하게 유지한다.
- gather 결정성: 모든 destination이 같은 입력으로 같은 예측을 계산해야 한다. 같은 셰이더·같은 텍스처 사용.
- CSP pfxWindscreen 입자 용량과 갱신 Hz는 CPU 코드에서 확정하지 못했다.
- 차량 유리 재질의 rain 맵 최종 소비 경로는 미추적(§1-11).

## 10. 재현 자료

- 디스어셈블러: `docs/tools/dxbc_disasm.py` (SM4/5, FXC 출력과 대조 확인. aoffimmi 포함).
- 주요 asm: `docs/diagnostics/2026-10-25/csp728_rain_re2/` (pfxWindscreen_*, pfxRainScreen_*, accRainScreen_*, accNeckHelmet_ps_*, main_fx smGlass).
- 내장 ZIP: DLL offset 0x2871000 (`shaders.zip`, `internal/shader-tpl/*.fx`, `textures/rain_fx/*.dds`, `internal/configs/rain.zip`).
