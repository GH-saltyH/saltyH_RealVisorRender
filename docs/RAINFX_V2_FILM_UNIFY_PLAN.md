# RainFX v2 — 얇은 물 통합 구현 계획 (θr 40°, 2026-11-13)
- 근거:
  - `RAINFX_V2_FILM_UNIFY_RESEARCH.md`(§2 통합 물리, §7 배수, §8 프로토타입, §9 표현)
  - `RAINFX_V2_TRAIL_REVIEW2.md`(TR0–TR3)
- 사용자 결정: 후퇴각 θr = 40°. 높이 지도 해상도는 유지(0.59 mm).

## 0. θr 40°의 결과 (계산)
- 정적 각 θs = contactDeg 60°(방울 캡 부피), 전진 θa = 2 θs − θr = 80°(히스테리시스 40°), 젖음에 따른 감소 θr (1 − 0.35 wet).
- **trail 문턱 U\*:**

|젖음|U\*|
|---|---|
|마른 면|~200 mm/s(지금 28°: 68)|
|wet 0.5|~115 mm/s|
|wet 1|~57 mm/s|

  - 240 km/h에서 r 0.2 / 0.3은 건조(s 0.39 / 0.74), r 0.5 / 1.0만 trail(s 1.7 / 3.9). → 막대의 수가 크게 준다.
- **선의 안정성:** 선의 가장자리 각(상한 24°) < θr(wet) 최소 26°다. → **머리 뒤 선은 언제나 끊어진다.** 이어진 물줄기는 공급받아 흐르는 h의 rivulet뿐이다(배수 그림과 일치).
- **공급 없는 막의 수명(V_d 156–220 mm/s):**

|형태|수명|
|---|---|
|선|0.5 ms|
|패치 2 mm|5 ms|
|lamella 6 mm|17 ms|
|sheet 15 mm|46 ms|
|40 mm|0.13 s|

  - 퍼들 높이 e_c 1.85 mm.

## 1. 단계 A — 표면 매개변수와 공용 규칙 (F0 + F1)
- **init.lua:**
  - surfThetaRDeg 40(새 기준).
  - trailThetaRDeg ← θr, sheetRecedeDeg ← θr, hysteresis ← θa − θr. contactDeg(θs) 60 유지. UI는 θr 하나.
- **공용 함수(common.hlsl):**
  - r2RecedeAngle(wet): 젖음 하나. wet = max(깊이 기반 r2Wet, 공급 기반 r2WetTx).
  - r2DewetSpeed(W, wet) = 72 m/s · θ³ / (9 ln(W/λ)).
  - r2FedRate(W, wet) = 2 V_d / W.
  - r2BeadRow(hw, h0) → (간격 9 hw, 구슬 r).
  - r2MobileLen(h) = γ Δcosθ / (τ + ρ g_t h)(τ, g_t는 Lua 상수).
- **trail 규칙(r2TrailRule)과 sheet 가장자리 / 핀이 위 함수만 쓴다.**
- 눈에 보이는 변화: trail이 큰 머리에만 생긴다(240 km/h r ≳ 0.45 mm). sheet 메니스커스 각이 50 → 40°.
- 비용 0.

## 2. 단계 B — trail (TR0 → TR1 / TR3 → TR2b)
- **TR0 substep 기록:**
  - trail 패스를 cells substep마다 실행한다(그 substep의 S_next; ±2 셀 후보 + wm의 선분-사각형 컷).
  - TG를 RGBA32F로 바꿔 선 기하와 이번 프레임 깊이를 함께 담는다. field 패스는 trail 후보를 다시 모으지 않고 TG의 깊이를 읽는다(R 장부는 field 1회 유지).
  - → 경로 전체가 끊김 없이 기록되고, 머리의 질량 손실과 장부가 일치한다.
- **TR1 끊어짐:**
  - 이번 프레임에 놓이지 않은 선 중 θ_line < θr(wet)인 것(θr 40°에서는 사실상 모두)은 이번 프레임에 구슬이 된다(field R → 0).
  - 같은 판정을 field / cells / visor가 F_prev + TG_prev로 한다.
- **TR3:** 선 렌즈는 새로 놓인 선(이번 프레임)만 그린다 = 머리 뒤 한 프레임 꼬리.
- **TR2b 구슬:**
  - 구슬 반경 r_b = (9 hw · (4/3) h0 hw / K)^(1/3) ≈ 0.3 r_head, 간격 9 hw ≈ 2.2 r_head, 지터(간격 ±30 %, 크기 0.75–1.2, 옆 ±0.3 hw).
  - **움직이는 크기(r_b ≥ 그 속도의 depin 반경)는 셀 방울로 태어난다.** cells 마지막 substep에서 선이 지나는 셀마다 1개, 같은 해시. 고속에서는 대부분 여기에 해당 → 달린다.
  - 더 작은 구슬은 visor가 선 기술자에서 그린다(정지, field R의 수명: 증발, 수거, S1, T1).
- 비용: trail 패스 0.03–0.05 ms × substeps, visor +0.01–0.03 ms. → 구현 후 실측. substep이 많을 때 0.2 ms를 넘으면 대안(셀 해상도 trail 기록)을 낸다.

## 3. 단계 C — sheet 배수 (F5 + F3, sheet 켬)
- **F5-1 이동 판정:** sheetPinMM(두께 0.3 mm) → 길이 기준. 연결 막 창 / 패치 크기 ≥ r2MobileLen이면 전체가 움직인다. 240 km/h ~1.6 mm, 정지 15–220 mm.
- **F5-2 수송:** Courant 0.24 상한 업윈드 → 플럭스형 semi-Lagrangian(FFSL, 질량 보존, Courant > 1). 속도 상한 = 물리 법칙(sheetUMax 상향). sheetSub 8 → 2–4.
- **F3 가장자리 후퇴:**
  - 공급이 r2FedRate보다 적은 막의 가장자리 텍셀은 물을 안쪽 테두리로 옮긴다(V_d dt / 텍셀만큼, 질량 보존). 흐르는 막에서는 옆으로 좁아져 rivulet이 된다.
  - 줄어든 덩어리는 bead 패스(W1t)가 캡으로 만든다.
  - W1k 영구 잔류와 thinRate 소멸(질량 손실)을 없앤다.
- **F5-3:** 배수 수렴(W1r), 가장자리 유출, S1 haze 흡수는 유지한다.
- 비용: FFSL은 기존 유량과 비슷한 Load. substep을 줄이면 순증 0–0.03 ms.

## 4. 단계 D — 선택
- F4: field R을 B로 합쳐 물 장부를 하나로(TG = B의 서브텍셀 보조 정보). C 뒤에 평가.

## 5. 순서와 검증
- **A → B → C.** 각 단계마다 FXC, 게임 검증, 비용 측정을 하고, 문서 / Projects에 기록한다.

|단계|게임 확인|
|---|---|
|A|trail을 남기는 방울 수, 속도별 차이, sheet 가장자리 모습|
|B|240 km/h 추종에서 경로가 끊기지 않는지, 막대가 없는지, 꼬리 + 구슬 줄, 구슬이 달리는지, 정지 시 구슬 줄|
|C|sheet가 생긴 자리에서 하류로 흐르는지, rivulet 수렴, 배수, 남는 방울 / 구슬|

- 주의:
  - 기본 sheetOn은 false다. 배수 그림(C)은 sheet 켬에서만 나온다 → C 검증 뒤 기본값을 다시 정한다.
  - A / B는 sheet 켜기 / 끄기 모두에 적용된다.

## 6. 구현 기록 — A + B1 (2026-11-13)
- **sheetOn 기본값 true**(사용자).
- **A (init.lua R2:syncSurface, 매 프레임):**
  - surfThetaRDeg 40 → trailThetaRDeg = sheetRecedeDeg = θr.
  - hysteresisDeg = acos(cos θr − pinCoat) − θr. 방울 depin에 맞춘 Furmidge Δcos 0.18을 그대로 두므로 θa ≈ 54°, 히스테리시스 14°다. §0의 θa 80°가 아니다: 방울 운동 보정(F4b)을 깨지 않으려는 선택.
  - UI는 'Coat receding contact angle' 하나(sheet 각 슬라이더 제거).
  - θr 28 → 40°에서 방울 동적 저항 변화는 작다(P.speed 240 km/h: r 0.5 0.347 → 0.311, r 1.0 0.774 → 0.745 m/s).
- **A 공용 함수(common.hlsl):** r2RecedeRad(wet), r2DewetSpeedMMs, r2FedRate, r2WetU(F, t) = max(깊이 젖음, 공급 젖음). trail 규칙, 방울 한 걸음(r2Predict), field, trail 패스가 r2WetU를 쓴다.
- **B1:**
  - **TR0:** trail 패스를 cells substep마다 실행한다(gR2Dt = i h). TG는 RGBA32F이고 `tgshared.hlsl`의 r2TgPack을 쓴다(z = 각 + 8 × 태그(frame mod 1023, 1023 = 지난 선), w = hw + 2 × 깊이 / 1e-4). field는 이번 프레임 태그의 깊이만 R에 놓는다(5×5 trail 후보 재수집 제거).
  - **TR1:** 태그가 지난 선 = 끊어진 선(구슬 줄). T7 선 흐름은 새 선에만 적용한다(사실상 없음 → 흐르는 rivulet은 단계 C의 h).
  - **TR3:** visor는 새 선만 rivulet 렌즈로 그린다(머리 뒤 한 프레임 꼬리).
  - **TR2b:** 지난 선은 r2BeadRow(간격 9 hw, 캡 반경 ≈ 1.4 hw ≈ 0.3 r_head) 구슬 3개(가장 가까운 것 ±1)를 같은 커널 union으로 그린다. 위치는 바이저 mm 고정 위상, 정수 해시 키(선의 가로 오프셋 + 각). 물은 field R 그대로다.
  - `tgshared.hlsl`은 Lua가 common.hlsl / cand.hlsl 앞에 붙인다(체커도 같게).
- **보류(B2):** 움직일 크기의 구슬을 셀 방울로 태어나게 하기. B1에서는 구슬이 그려진 정지 캡이다(고속에서도). B1 게임 검증 뒤 결정.
- DXC 24 패스 OK.
