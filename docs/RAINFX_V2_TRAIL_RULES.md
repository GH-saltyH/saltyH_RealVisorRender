# RainFX v2 — trail 규칙 (rev47l, 2026-10-29)

rev47k 리뷰: Light Rain에서도 움직이는 작은 방울이 길고 두꺼운 trail을 그렸다. 어떤 방울이 건조하게 흐르고 어떤 방울이 trail을 남기는지, 그리고 두께, 길이, 속도를 정하는 규칙을 하나의 물리 기준으로 정리한다. 설계 규칙(`ref_OBJECTIVES/rule_trail.txt` 1–12)과 레퍼런스 영상에 맞춘다.
검산 도구: `docs/tools/rainfx2_trail_rules.py`.

## 1. rev47k 진단
- **runback 속도 버그:** rev47b–k 코드는 `clamp(runbackK·u, vMax 0.08, runbackMax 0.06)`였다. 하한이 상한보다 커서 날려 가는 방울은 **크기와 무관하게 모두 0.06 m/s**였다. 그래서 모든 runback 방울이 같은 속도로 미끄러지며 trail을 남겼다.
- trail 깊이 공식(rev45–47k)에는 "trail이 생기지 않는 영역"이 없었다. 크기 계수 smoothstep(0.12–0.36 mm)만 있어서 움직이는 방울은 거의 모두 줄을 그렸다.
- **레퍼런스:**
  - verySmall(Light, 고속): trail 없음.
  - medium(중간, 고속): 크기 있는 방울만 짧고 가는 trail.
  - large(많은 비, 고속): trail이 두껍고 자주 생긴다.
  - WFShape(정지/저속 측창): 대부분의 방울은 정지해 있다. 크게 미끄러지는 방울만 줄을 남긴다(프레임당 1–2개).
- 결론: trail은 **드문 현상**이다. 크고 빠르고 젖은 흐름에서만 생긴다.

## 2. 물리 기준: 접촉선이 따라가지 못할 때만 물이 남는다
- 미끄러지는 방울의 뒤쪽(receding) 접촉선의 동적 각은 속도에 따라 줄어든다(Cox–Voinov): θd³ = θr³ − 9 Ca ln(r/λ).
- θd가 0에 닿으면 뒤쪽이 모서리(corner)에서 첨점(cusp)이 되고, 물을 남기기 시작한다. 처음에는 작은 방울 줄(pearling), 더 빠르면 연속된 rivulet이 된다(Podgorski–Flesselles–Limat 2001, Le Grand–Daerr–Limat 2005).
  - 문턱: **Ca\* = θr³ / (9 ln(r/λ))**, Ca = μU/γ = U / 72 m/s, λ = 1 nm.
- 젖은 표면은 receding 각을 낮춘다(앞선 물자국과 미세 물방울 위를 지난다). θr = θr,dry (1 − wetK · wet).
- 큰 방울이 먼저 문턱을 넘는다. 힘은 r²(공기)와 r³(중력)에 비례하고 고정력은 r에 비례하므로, 큰 방울일수록 빠르다. 작은 방울은 문턱 아래에서 건조하게 흐른다.

## 3. 규칙 (rev47l 구현)

| # | 규칙 | 구현 |
|---|---|---|
| T1 | 방울 속도는 크기에 따라 달라진다 | runback = max(크리프, min(runbackK · u_top · excess, runbackMax)), excess = 1 − shedK·Fpin/F_air |
| T2 | trail 여부 | s = Ca/Ca\* ≤ 1이면 **건조**(trail 없음, 질량 손실 없음) |
| T3 | 젖음 | θr = 28° × (1 − 0.35 · wet), wet = r2Wet(haze, 수막, trail 물) |
| T4 | 폭 | hw = 0.5 · widthK · r · √(1 − 1/s). 문턱 근처는 가늘고(pearling), 빠를수록 넓다 |
| T5 | 깊이 | h0 = min(LL · r · Ca^(2/3), 0.5 · hw · slopeMax). Landau–Levich: 빠를수록 두껍다 |
| T6 | 질량 | 방울은 이동 거리마다 (4/3) h0 hw를 잃는다. 큰 방울이 긴 trail을 남기고, 작아지면 문턱 아래로 내려가 trail이 끊긴다 |
| T7 | 흐름 | 고정 깊이 0.02 mm 위 초과분은 자기 선을 따라 흐른다(rev47k). 빠른 trail은 빨리 빠지고 느린 trail은 오래 남는다 |
| T8 | 잔류와 재응집 | 잔류선은 pearling으로 방울이 된다. 비율은 셀당 0.6 /s × (0.25 mm / hw), 0.5–6배 범위. 가는 줄일수록 빨리 끊긴다. 남은 방울은 다른 물과 합친다 |
| T9 | haze | 지나간 면적의 haze가 trail 물에 더해진다(기존) |

## 4. 결과 표 (`rainfx2_trail_rules.py`, θr 28°)
- 문턱 속도 U\*: 건조 68, wet 0.3 → 48, wet 0.6 → 33, wet 1.0 → 19 mm/s.

| 상황 | trail이 생기는 반지름 | 폭(2hw) | 깊이 |
|---|---|---|---|
| 정지, 덜 젖음(wet 0.2) | 없음(r 1.5 mm도 45 mm/s, s 0.85) | – | – |
| 정지, 젖은 흐름(wet 0.6) | r 1.5 mm(빠르게 미끄러지는 가장 큰 방울) | 0.39 mm | 44 μm |
| 100 km/h, wet 0.4, 30° | r ≥ 1.0 mm(1.0은 문턱 근처라 매우 가늘다) | 0.12–0.41 mm | 13–47 μm |
| 250 km/h, wet 0.6, 20° | r ≥ 0.6 mm | 0.20–0.51 mm | 22–57 μm |
| 250 km/h, wet 0.6, 50° | r ≥ 0.4 mm(r 0.25는 폭 0.03 mm로 생기자마자 끊긴다) | 0.13–0.51 mm | 14–57 μm |

- 레퍼런스와 맞춰 보면
  - Light, 건조한 흐름: 작은 방울은 trail이 없다.
  - 중간 비: 크기 있는 방울만 가늘고 짧은 trail을 남기고, pearling으로 금방 끊긴다.
  - 많은 비(wet → 1): 문턱이 19 mm/s로 내려가 더 많은 방울이 더 넓은 trail을 남긴다(thickTrail).
  - 정지: 크고 빨리 미끄러지는 방울만 줄을 남긴다.

## 5. 설계 규칙과의 대응 (`rule_trail.txt`)

| rule_trail | 반영 |
|---|---|
| 1–3 trail은 물의 일부, 머리 질량 손실 | T6, 질량 보존 pearling(T8) |
| 4 굵기, 길이, 남는 정도 = 크기, 젖음, 속도 | T2–T6 |
| 5 젖을수록 가능성이 크다 | T3 |
| 6 클수록 가능성이 크고, 작으면 건조하게 흐른다 | T1(크기 → 속도) + T2 |
| 7 (검증됨) 빠를수록 두껍고, 문턱 근처는 pearling | T4, T5 |
| 8–9 느린 trail은 느리게, 빠른 trail은 빠르게 빠진다 | T7(깊이 ∝ 속도, 흐름 ∝ h², h) |
| 10 머리에 완전히 종속되지 않는다. 남고 재응집한다 | T7 잔류 + T8 |
| 11 haze 흡수 | T9 |
| 12 저비용 | 셀 해시 사건, 선 형상 텍스처, Load 1–2번 |

- 충돌 검토
  - 규칙 7 원안("느릴수록 가능성이 소폭 높다")은 검증에서 뒤집혔다. 빠를수록 두껍고, 문턱 아래는 trail이 없다.
  - 규칙 8 "느린 trail은 느리게 소멸"은 T7로 성립한다. 느린 머리는 얇은 trail을 남기고, 얇은 trail은 h²에 비례해 느리게 흐른다.

## 6. 파라미터 (Physics 패널)

| 이름 | 기본 | 의미 |
|---|---|---|
| trailThetaRDeg | 28 | 건조 코팅의 receding 각. 낮추면 trail이 많아진다 |
| trailWetK | 0.35 | 젖음에 따른 각 감소 |
| trailLL | 5 | 깊이 계수(× r Ca^(2/3)) |
| trailWidthK | 0.5 | 고속에서의 최대 폭(× r) |
| trailSlopeMax | 0.45 | 단면 경사 상한 |
| trailPinMM / trailFlowK | 0.02 / 1 | 흐름(T7) |
| pearlRate | 0.6 | 셀당 기본 pearling 비율(T8) |
