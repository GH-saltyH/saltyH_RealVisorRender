# RainFX s78 — P1 게임 판정과 P2 크기·유입·충돌 계산 준비

Date: 2026-10-14. Status: ACTIVE — P1 게임 결과 기록, P2 진단 계산과 UI 구현/검증 완료. GPU birth/event commit은 아직 연결하지 않았다.

## 1. 이번 단계와 남은 구현

P1의 정차 93→76 FPS, 물방울 고착/이동 및 표시 배율 독립 관찰은
`RAINFX_S77_SI_MOTION_PREVIEW.md` User result에 기록했다. 일부 큰 방울의
130 km/h 위빙 즉시 반응은 미해결 교정 항목이다. m/c 완화 시간은 .65 mm에서
2.19 ms로 작으며, 작은 기존 물리 크기와 shape=80의 점성 근사는 한 프레임 안에
속도를 새 힘에 거의 맞춘다. 큰 D_eq=2.25 mm에서는 26.20 ms가 된다.
관찰만으로 버그/실제 접촉선 운동을 확정하지 않는다. 출력 gain으로 물리 마찰을
바꾸거나 궤적을 화면에서만 평활화하는 보정은 적용하지 않았다.

새 `rain_birth_model.lua`는 P2의 **진단용 계산 모듈**이다. GPU 상태 및 기존
튜닝/셰이더는 s77과 동일하다. accepted P1에 미완성 공급원을 넣지 않았다.
DSD와 유량의 검증을 생략한 채 기존 occupancy/respawn에 새 크기만 연결하면
총 물 공급이 D³에 따라 폭증하고, film/micro의 물을 이중 생성할 수 있기 때문이다.

다음 구현에서 해결해야 할 연결은 다음과 같다.

- 실제 transformed KN5 normal/면적·차폐에 대한 encounter CDF와 birth 유량.
- GPU 양 bank가 같은 generation의 입사 사건을 읽고 한 번만 commit하는 event descriptor.
- material/wet-state impact LUT의 잔류/필름/미세/유출 fraction과 impulse 교정.
- 슬롯 포화/표면 이탈/병합을 포함하는 원장과 unresolved/runoff 계량.
- 온도별 물성; 현재 진단 충돌은 20°C 기준이며 기온=바이저 온도로 주장하지 않는다.
- P3 실제 deposit/film/micro/evaporation 및 그 재고에서 나오는 trail/sheet.

**P2 완료나 새 trail 가동을 의미하지 않는다.** 기존 P1 birth-size profile도
이번 단계에서는 계속 사용한다. 아직 바뀌지 않은 실제 diameter를 출력 gain으로
보상했다고 주장하지 않는다.

## 2. 연속 대기 크기 분포

128개의 log-D 구간을 한 번만 만들고, seed의 지원 범위/그룹 경계를 grid에 맞춰
삽입한다. 각 그룹은 log-D 대칭 triangular probability다. 모든 seed는
동일한 bin 경계에 있지만 그룹과 확률은 각각 다르다. 구간 대표값은 log midpoint이며
실제 범위 바깥의 방울을 만들지 않는다. histogram 및 물량 계산은 같은 대표값을 쓴다.

| Seed | 그룹 경계, mm | 그룹 개수 확률 | 의도 |
|---|---|---|---|
| drizzle | .1 / .3 / .5 | .90 / .10 | 미세 다수 |
| general | .5 / 1.2 / 2.5 / 4.5 | .65 / .30 / .05 | 일반 + 큰 꼬리 |
| tail | .5 / 1.4 / 3 / 6.3 | .55 / .35 / .10 | 작은 방울 유지 + 더 큰 꼬리 |
| windrich | .3 / 1.1 / 2.4 / 4 | .75 / .23 / .02 | 강풍 추정에서 작은 방울 우세 |

위 그룹 경계는 교정 전 seed다. 사용자 대표 직경 .25/1.15/2.25/1.55 mm를
이 분포의 number mean이라고 강제하지 않는다. 실제 number mean, incident mean,
2 mm 초과 volume share를 `checks.json`에 기록했다. tail의 소수 큰 방울이 체적의
대부분을 운반하는 결과도 함께 공개한다. 관측 DSD로 확인된 날씨 모델은 아니다.

가중치는 s73의 q/c/b smoothstep을 따른다. liquid intensity와 **ambient** wind만
대기 분포를 조정하고, 차량속도/상대풍은 encounter 단계에 들어간다.
track wetness, track water, RH 및 display gain은 DSD/직접 강수 공급을 만들지 않는다.
0–4 override는 자동 추정 또는 명시적 seed를 고른다. weather 이름에 직접 대응하지 않는다.
humidity/track spray가 불필요하다는 뜻은 아니며, 각각 건조/별도 검증된 spray 입력의 역할이다.

## 3. 유입량과 입사 편향

`R=R1*liquidIntensity^p`. R1=20 mm/h, p=1은 **시작용 estimated calibration**이며
CSP intensity=1이 실제 20 mm/h라는 사실을 뜻하지 않는다. UI에서 변경할 수 있다.

`N0 = (R/3,600,000) / E[V_m3 * terminal_m_s]`.
참조 평면의 각 bin 도달 개수는
`N0 * P_number(bin) * max(0,-dot(air - terminal*worldUp, normal)) * exposure`.
따라서 sampling도 number CDF와 encounter-weighted number CDF를 구분한다.
normal은 정규화하고 퇴화 법선은 reject한다. 면적 단위는 m²이며 결과는
`drops/m²/s`, `mm³/m²/s`. 실제 바이저 면적/공급으로 표현하지 않는다.

정지·위쪽 평면에서는 모든 seed가 정확히 설정한 R의 체적 flux를 재현한다.
반대 평면에서 입사가 없으면 sample도 nil이다. 동일 intensity에서 큰 방울
분포를 선택하면 개수가 줄어들어 체적 flux를 유지한다. 차량 상대풍이 강해지면
실제 방향/법선에 따른 추가 encounter가 발생하며 scalar car speed를 법선속도로 쓰지 않는다.

낙하 속도는 Frisch/Atlas의 piecewise 근사를 mm 단위로 구현했다:
`30*D²` (<.11), `4.1665*D-.0833` (.11–.86),
`9.65-10.3*exp(-.6*D)` (>.86), m/s. 작은 방울에 Atlas 지수식을 그대로
외삽해 음의 낙하속도를 만들지 않는다. 구간 연결은 근사식의 작은 불연속을 그대로
기록하며, 밀도/고도 보정과 난류는 아직 포함하지 않았다.
근거: [Frisch/Atlas piecewise를 사용한 연구, Eq. 7](https://amt.copernicus.org/articles/18/4857/2025/).

## 4. Virtual impact 계산/원장 계약

`impact()`는 입사 법선/tangent, 실제 D_eq³ 체적·kg, We_n/Re_n/Oh를 계산한다.
입사속도는 relative air에서 낙하를 뺀 world 벡터를 법선에 투영한다.
뒤쪽/퇴화 법선, 유효하지 않은 물성 및 NaN 입력은 commit 대상이 아니다.

`partition()`은 material LUT가 넘긴 네 fraction을 검증한다. 각 값은 음수가 아니고
합=1이어야 하며, tangent impulse fraction은 0–1이다. 체적을 attached/film/micro/outflow로
분할하고 초기 부착 속도는 입사 접선속도의 해당 비율 이하로 둔다. 같은 액체에서
부착된 체적에 배분된 운동량보다 큰 값을 만들지 않는다. 이 원장 helper는 사건을
저장/소비하거나 실제 슬롯/필름에 물을 쓰지는 않는다.

보편적인 `We>상수` splash law 및 임의 고정 잔류율은 채택하지 않았다.
실제 반발/비산은 재질·기체·젖음 상태에도 의존한다.
근거: [drop impact review](https://doi.org/10.1146/annurev-fluid-122414-034401).

## 5. UI·설치·비용

RainFX → Weather inputs and physical units (P0):

- 기존 P1 controls 아래 `20 C reference D_eq=1.15 mm: viscous m/c ...` 진단값.
- `Enable P2 birth diagnostics (no simulation change)` 기본 OFF.
- estimated rate at I=1, intensity power, DSD seed override.
- number mean·N0·추정 R·네 mixture weights.
- `Log P2 reference-plane encounter`: 위쪽 및 차량 forward **참조 평면**만 수동 로그.
  actual visor normal/차폐로 오해하지 않도록 이름과 로그에 구분한다.

진단 ON 시 최초에 모듈/128 bins를 한 번 만들고 프레임 갱신은 cached seed moments의
O(4) 연산만 한다. 128-bin encounter/sampling loop는 수동 진단/검증에만 사용한다.
새 GPU pass/texture/readback/per-drop CPU stamp가 없다. 기본 OFF일 때 모듈도 로드하지 않는다.
40,000 프레임 LuaJIT fixture에서 GC 후 retained growth <16 KiB 통과했다.
이는 실게임 CPU/GPU 시간 측정이 아니다. 입력/UI 문자열은 기존 방식이다.

`install_s75_inputs.ps1`의 hash-guarded companion 목록에 `rain_birth_model.lua`를 추가했다.
새 모듈 누락은 진단 오류로 표시하고 P0/P1 실행을 실패시키지 않는다.
진단 checkbox/값은 아직 material settings에 영구 저장하지 않는다.

## 6. 검증

`docs/tools/check_s78_birth_model.py`는 실제 LuaJIT 모듈과 실제 main/UI hook을 실행한다.

- 네 seed 확률 정규화/범위/단조 quantile; number/volume 분포를 함께 기록.
- 설정한 수직 체적 flux와 1/4 exposure 비례를 같은 bin 원장으로 재현.
- 연속 mixture, ambient wind vs relative air 구분, track/RH/display 독립 및 liquid=0 공급 없음.
- 법선 기반 We/Re/Oh; fraction sum, 비음수 체적, 접선 impulse 상한, 무입사/NaN reject.
- opt-in one-time module load, default OFF, manual logging, missing diagnostic module 격리.
- 반복 갱신 allocation bound와 realvisor.lua syntax.
- s77 대비 기존 물리/광학 셰이더·환경/단위 helper·설정 hash 불변.

결과: `docs/diagnostics/2026-10-14/s78/checks.json`, `source.diff`.
사용자의 Git stamp를 위해 변경은 로컬에 남겼으며 자동 commit/push하지 않았다.
