# CSP 와이퍼와 앞유리 물길 분석 + 시제품 (2026-11-18)

## 0. 자료와 판본 (§4에서 0.3.1-preview2 DLL과 대조 완료)
- 소스: 프로젝트의 `acc-shaders-master/custom/particles/windscreen/pfxWindscreen_*`, `custom/rain/accRainWindscreen_*`
- 게임 판본 `lights-patch-v0.3.1-preview2-full`의 셰이더는 dwrite.dll 안에 컴파일되어 있다(`extension/shaders.zip`은 172바이트 껍데기). 그래서 바이트 단위 대조는 할 수 없다.
  - 0.3.1 Changelog의 앞유리 비 관련 항목은 'Windscreen reflections no longer crash when the scene changes live' 하나뿐이다.
  - 아래 분석은 acc-shaders 공개 소스 기준이다.
- 엔진 쪽(C++)의 패스 순서와 상수(gFadeFast / Normal / Slow, gScale 등)는 소스에 없다. 셰이더 입출력에서 역으로 읽었다.

## 1. CSP 앞유리 비의 구조(물리 유체가 아니라 세 층의 그림)
1. **방울 = GPU 입자(pfxWindscreen_cs_simulate):** 앞유리 UV 공간의 pos, velocity, size, sticky, life, moved, squished
   - **가속:** 차 기준 세계 속도(gVelocity: 공기 + 중력)를 면에 투영하고, 노이즈로 옆으로 미는 성분(gVelocitySide0/1)과 차 들림(gCarLift)을 더한다.
   - **붙잡힘:** sticky가 0보다 크면 멈춰 있다. sticky는 시간, 주변 물 속도, 주변 밀도, 가속 크기만큼 줄고, 큰 방울일수록 빨리 줄어든다.
   - **흐르는 방울은 작아진다:** size −= |v|·dt. 물을 뒤에 남긴다는 뜻이다.
   - **다른 방울의 자취로 끌림:** 'Force moving raindrops to trails of other raindrops'. 진행 방향 앞 0.02의 좌우 ± 0.01에서 trail(v) = sat(z − 2a)를 비교해 젖은 쪽으로 조향한다. 그래서 물길이 합쳐지고 같은 길이 반복된다.
   - **밀도 저항:** 주변 방울이 많으면(blurred a) 끌림이 커지고 수명이 준다.
2. **물 지도(water map, RGBA):** xy = 방울 속도 × 10, z = 물이 있던 자리(자취), a = 지금 방울
   - 그리기(pfxWindscreen_ps): 방울을 원반으로 찍는다. 와이퍼에 밀리는 방울은 z = 0이다.
   - **이동 패스(accRainWindscreen_move):**
     - 매 프레임 지역 속도로 0.002만큼 이류한다.
     - a = sat(a·1.08 − 0.04) − 0.005·(1 − |v|): 방울 자국은 몇 프레임 만에 사라진다.
   - **waterFade:**
     - z는 노이즈로 빠름 / 보통 속도가 갈리며 줄어든다(gFadeFast / gFadeNormal). 끊긴 듯 고르지 않게 마른다.
     - 와이퍼 아래에서는 z × (1 − wiper.a)로 지워진다.
   - **결과:** **물길 = 방울이 지나간 자리의 z가 남은 것**이다. 두께는 시각용(정규화 0–1)이다. 노이즈 페이드로 조각나며 사라진다.
3. **와이퍼:**
   - **블레이드 지도(accRainWindscreen_wipers / wipersProjection):** 와이퍼 메시를 앞유리 UV로 투영한다. xy = 블레이드 속도, z = 고무를 따라간 위치(0–1, gPosMin부터 거리), a = 덮임.
   - **입자:**
     - 블레이드가 움직이면 방울은 블레이드 속도의 5–25 %로 밀린다(moved). 위치는 1.5 × 블레이드 속도로 옮겨진다. 앞에 물이 쌓인다.
     - 0.2 %의 방울은 squished가 되어 블레이드에 끌려가며 더러운 자취를 남긴다.
     - 블레이드가 멈춰 있으면 방울을 옆으로 밀어내고 붙잡는다.
   - **고무 오염(rwWiperDirt, 256 × 1):** 블레이드에 맞은 방울(0.2 %)이 그 고무 위치에 오염을 더한다. 오염은 매 실행 ×0.95 − 0.05로 빠진다.
   - **줄무늬(accRainWindscreen_finalizeTraces):**
     - x = max(new, prev − fadeSlow − 블레이드 × fadeFast × 10 + 가장자리 항)
     - new = lerp(0.1, 0.5, noise(고무 위치, 시간)) × dirt(고무 위치) × [지난 프레임 블레이드 자리] × 0.7
     - **더러운 고무 위치마다 블레이드 운동을 따라 호 모양의 얇은 물 줄무늬가 남는다.**
     - 쓸린 영역 가장자리(waterEdge: 블레이드 흐림 × 주변 물)에는 물이 쌓이는 띠가 생긴다.
   - **응결 / 손자국(splashes y, z):** 별도 층이다.
4. **렌즈(accRainWindscreen_finalize):**
   - 높이 = max(z, w)를 mip 1.5로 흐린 값이다. 법선은 ± 0.0005 UV 차분이고, 그것으로 굴절한다.
   - 가장자리가 부드럽고 흐린 물이다.

## 2. 시제품(`docs/tools/rainfx2_csp_wiper_proto.py`)
- NumPy로 위 논리를 평면 앞유리(480 × 270 UV)에 옮겼다.
  - 입자 sticky / 가속 / 노이즈 측면 / 자취 끌림 / 크기 감소
  - 물 지도 이류 / 빠른 a 페이드 / 노이즈 z 페이드 / 블레이드 지움
  - 블레이드(축 아래 회전, ± 50°, 2.2 s 주기), 밀기, 1D 오염, 줄무늬, 가장자리
  - 높이 = max(z, 줄무늬)의 기울기 굴절
- 결과:
  - `docs/images/rainfx2_csp_wiper_proto.png`: 0–8 s, 2 s부터 와이퍼
  - `docs/images/rainfx2_csp_wiper_layers.png`: a, trail = z − 2a, 줄무늬, 고무 오염
- 관찰:
  - **물길:** 흘러내리는 방울이 수직의 벌레 모양 자취(z)를 남기고, 노이즈 페이드로 조각나며 사라진다.
  - **와이퍼:** 부채꼴을 지운다. 오염된 고무 위치(오염 지도의 봉우리)마다 호 모양의 얇은 줄무늬가 남는다. 앞쪽에는 밀린 방울이 쌓인다.
  - **한계:** 엔진 상수(fade 값, 입자 수, gScale)는 추정이다. 해상도가 낮아 모양은 거칠다. 판단 대상은 기제다.

## 3. 우리 프로젝트에 주는 시사점
- **CSP의 물길은 물리 막이 아니라 '방울이 지나간 자리의 그림'이다.**
  - 이어진 느낌은 (a) 자취로 끌리는 조향(같은 길 반복, 합류)과 (b) 노이즈로 고르지 않은 페이드(조각나는 끊김)에서 나온다.
  - 높이를 흐려 렌즈를 만들므로 가장자리가 부드럽다. 레퍼런스처럼 선명한 물길 가장자리(어두운 두 줄)는 우리 벡터 선 방식(B3)이 낫다.
- **가져올 만한 것(제안):**
  1. **자취 끌림:** 머리가 다른 방울의 최근 꼬리 / 물길(TT 또는 field)의 젖은 쪽으로 조향된다. 물길 합류와 같은 길 반복이 생긴다(레퍼런스 '유지되는 리뷸렛', 오염 C의 경로 자기 강화와 같은 방향). 우리 r2Predict에는 trail follow / film follow가 이미 있어 꼬리 쪽을 더하면 된다.
  2. **노이즈 페이드(고르지 않은 끊김):** 물길과 꼬리 끝이 마디로 끊기는 표현(B4)에 그대로 쓴다. 비용이 거의 없다.
  3. **고무 오염 1D + 줄무늬:** 바이저에는 와이퍼가 없지만 장갑으로 닦기 / tear-off 직후 같은 '닦는 사건'에 같은 기제(닦는 띠 지도 + 1D 오염 + 줄무늬)를 쓸 수 있다. 필요하면 별도 과제로 한다.
- 비용 참고:
  - CSP는 입자 수천 개와 앞유리 지도 몇 장(2048 급, mip 사용)이다.
  - 우리 셀 시뮬레이션은 이미 같은 역할을 한다. 1, 2를 더하는 비용은 표본 몇 개 수준이다.

## 4. dwrite.dll(0.3.1-preview2) 분해 대조 (2026-11-18, 사용자 요청: acc-shaders-master가 오래되어 갱신점 반영)
- **방법:** DLL을 읽기만 했다(수정 / 실행 없음).
  - 파일: `lights-patch-v0.3.1-preview2-full/dwrite.dll`, 142936360 bytes, SHA256 `f53f55aa7621420e8a7287df870a494bf477333afeea168f31ec8c203a05e948`
  - DLL offset 0x28B7A00의 내장 ZIP `shaders.zip`(저장 방식, 31905896 bytes, 6765 항목)을 꺼냈다. `__packed_data.ini`로 원래 경로와 해시 이름을 대응시켰다.
  - 앞유리 / 와이퍼 관련 `custom/` 47개 DXBC를 `docs/tools/dxbc_disasm.py`로 역어셈블했다. 결과는 `docs/csp/v0.3.1-preview2_windscreen_asm/`에 있다.
  - DXBC에는 RDEF(변수 이름)가 없다. 그래서 상수(리터럴)와 명령 구조로 소스와 대조했다.
- **셰이더 목록:** 바이너리와 acc-shaders 소스의 앞유리 / 와이퍼 셰이더 이름 집합이 같다(양쪽에만 있는 것 없음). `accWindscreenSurface_step0–2`도 소스 `general/`에 있다.
- **명령 수준 대조 결과:**
  - **같음:** move, waterFade, finalizeTraces, finalize, finalizeBlurred, velocity, blurTraces, narrowWipers, wipers_ps, wipersProjection, splashesProjection, nmgen, pfxWindscreen_cs_emit / vs / ps, wiperDirtFade
    - 리터럴 차이는 모두 컴파일러 접기로 설명된다. 예: lerp(0.0006, 0.0028) → 0.0022, 1.3 × 1.1 → 1.43, 3.6 / 0.877453 → 4.10278, 1.5 × 4.10278 → 6.15418, 0.8 × 4.10278 → 3.28223, 3 / 16, 21 × 0.8 → 16.8, lerp(50, 1000) → 950
    - waterFade의 'min(z, 1 − gFading)'은 cb12[1].x로 미리 계산된 값과 비교한다.
  - **바뀐 곳(1곳):** `pfxWindscreen_cs_simulate`
    - 와이퍼 아래의 방울이 '고무 오염을 더함'과 'squished(블레이드에 끌려감)'가 되는 확률이 **상수 0.2 %(frac(...) > 0.998)에서 파라미터(cb8[7].w, 'frac(...) < 값')로** 바뀌었다.
    - 난수 씨앗도 바뀌었다: frac(rand × 77.2527 + 0.69199), frac(rand × 72.2685 + 0.17249).
    - 나머지(가속, sticky, 자취 끌림 −0.003 / 0.02 / 0.01 / mip 2.5, 끌림 lerp(30, 10, edge), 밀도 저항, lvMult 1000, 이동 상한 0.008, 크기 감소, 공기 저항, fly-off, 충돌)는 소스와 같다.
  - **CPU 쪽(문자열로 확인한 것):**
    - `wipers_trace_impl` / `trace_piece` / `car_wiper_traces`, 설정 `WIPERS_TRACE`, `USE_MESH_FOR_TRACES`, 'Custom trace, starting / ending point'
    - 도구 문구: 'Animated wipers use their brush shape (set in Curvature Following) to clear water from windscreen by default … define shapes manually with up to four water clearing lines per wiper or simply switch to mesh mode'
    - 이것은 블레이드 지도(wipers 텍스처)를 만드는 방법(브러시 모양 / 수동 선 4개 / 메시)이다. 셰이더 쪽 물 규칙은 같다. CPU 계산식은 이번에 분해하지 않았다.
- **결론:**
  - 0.3.1-preview2의 앞유리 물길 / 와이퍼 셰이더 규칙은 acc-shaders 소스와 사실상 같다. 차이는 오염 / squish 확률의 파라미터화 하나다.
  - §1–3의 분석은 그대로 유효하다. 시제품은 그 확률을 파라미터(DIRT_CHANCE)로 바꿨다.
