# CSP 웅덩이(puddle) / 노면 물 API 조사 (PUD, 2026-11-06)

## 0. 목적 (사용자)
- **CSP 노면 값의 의미:** wetness = 노면 전체의 젖음, water = 굴곡진 곳에 고인 웅덩이.
- **목표:** 차가 실제로 웅덩이를 밟았는지를 분리할 수 있으면 spray / splash 모델(앞차, 자기 앞바퀴)을 더 정확히 만들 수 있다.

## 1. 조사 결과 (preview728 lib.lua 정적 분석)

| 경로 | 내용 | 판정 |
|---|---|---|
| `ac.StateSim.rainWetness` | "From 0 to 1, quickly goes to 1 as rain starts pouring, quickly goes to 0 when rain stops" | 트랙 전역 값. 위치 정보 없음 |
| `ac.StateSim.rainWater` | "Amount of puddles, should slowly move towards rainIntensity value" | 트랙 전역 웅덩이 양. 위치 정보 없음 |
| **`ac.StateWheel.waterThickness`** | "Water thickness in meters"(바퀴마다, `ac.getCar(i).wheels[0..3]`) | **유일한 위치별 값.** 접지점의 물 두께 → 웅덩이를 밟는 순간을 직접 볼 수 있는 후보 |
| `ac.StateWheel.contactPoint / surfaceType / surfaceExtendedType` | 접지점, 노면 종류 | 웅덩이 정보는 없음 |
| `physics.exportRacingLineAsync` | RainFX racing line(차가 지나가며 마른 정도)의 압축 블롭 | 형식 비공개, 온라인 동기용. 사용 불가 |
| `ac.debugRainRacingLine` | 디버그 표시 | 데이터 접근 아님 |
| 웅덩이 지도 직접 조회 | 해당 함수 없음(lib.lua 전체 검색: puddle 0건) | 없음 |

- **dwrite.dll 문자열(정적):** CSP가 웅덩이를 GPU에서 생성하고(Puddles: height / relief / final, textures\rain_fx\puddles.dds, PUDDLES_AMOUNT 오버라이드), GPU → CPU로 읽어 온다(Puddles / GPU-to-CPU, gtocpu_puddle).
  - CPU 쪽 웅덩이 지도는 물리(접지 물 두께)와 AI('Avoid puddles (look ahead one second)')가 쓰는 것으로 보인다.
  - 따라서 waterThickness는 wetness 기본 수막 + 그 위치의 웅덩이 깊이 + racing line 건조를 반영할 가능성이 높다. 정확한 식은 미확인이다(필요하면 역어셈블).
- CSP 자체 VFX('RainFX: windscreen splashes', 'nearby puddles', 'car wetness splashes')는 내부 기능이다. Lua에서 접근할 수 없다.

## 2. PUD-1 검증 프로브 (구현됨, 측정 시에만 차량 순회)
- **RainFX 탭 표시:** 'Wheel water (mm): own front / rear | lead / pack max / any car < 60 m'
- **CSV 열 추가(뒤에 5열):**
  - selfFrontWaterMM, selfRearWaterMM(자기 앞 / 뒤 바퀴 최대)
  - leadWaterMM(spray에 기여한 가장 가까운 차)
  - packWaterMM(기여 차량 최대)
  - aheadWaterMM(60 m 안의 앞차 아무나, 기여 여부와 무관)
  - −1 = 값 없음
- **확인할 질문:**
  1. 자기 차: 마른 노면 / wetness만 / 눈에 보이는 웅덩이를 지날 때 값이 구분되는가(웅덩이에서 순간 증가?). 단위와 범위는 얼마인가(mm)?
  2. AI 차량: 값이 채워지는가(0이나 −1로 고정되지 않는가)?
  3. 리플레이: 자기 차와 다른 차 모두 값이 나오는가? 라이브 주행과 같은 범위인가? (StateWheel.load는 리플레이와 원격 차에서 부정확하다는 문서 경고가 있다.)
  4. water / wetness 설정과의 관계(water 0 → 웅덩이 0?)
- **방법:** 'Record metrics CSV'를 켜고 웅덩이가 보이는 구간을 단독 주행(라이브 1회, 같은 구간 리플레이 1회)한다. AI 군집 뒤 주행 1회. 웅덩이를 밟은 시점을 Scene tag로 표시하거나 영상 시간으로 알려 주면 대응시킨다.

## 3. 결과에 따른 모델(PUD-2, 프로브 결과 후 결정)
- **waterThickness가 차량별로 유효하면:** spray 공급을 차량 / 바퀴별 물 두께에 연결한다. 전역 max(water, wetness)를 대체한다.
  - 미세 spray(구름): 앞차 속도 법칙 × g(바퀴 물 두께, 바퀴 평균 / 시간 평활)
  - splash(1–4 mm 탄도 방울): 웅덩이 진입 이벤트(물 두께의 급증) × 근거리 → 짧은 버스트. 레퍼런스 'puddle_largeWFSize'(앞바퀴가 웅덩이를 밟을 때만 국소 생성)가 대응 장면이다.
  - 자기 앞바퀴: 오픈휠의 앞바퀴 웅덩이 splash(spraySelf)를 같은 이벤트로 연결한다.
  - g(h)의 형태와 계수는 문헌(수막 두께에 따른 tyre spray / splash, Koppa; FHWA 2014)과 프로브 범위로 정한다.
- **유효하지 않으면(AI / 리플레이에서 0):** 자기 차 값만 쓴다(웅덩이 splash). 앞차는 전역 water / wetness를 유지하되, 위치 근사(자기 차가 같은 지점을 지날 때의 값을 앞차가 지나간 시각에 대응)를 검토한다.
- **비용(지침):** Lua 차량 순회(이미 spray.lua가 매 프레임 수행) + 바퀴 4개 필드 읽기. 할당이 없다. 새 패스 / 텍스처가 없다.

## 4. PUD-1 결과 (사용자, 2026-11-06)
1. **자기 차, 평지 < 100 km/h:** 0.9–1.0 mm이다. 앞바퀴를 눈에 보이는 웅덩이에 담그면 > 2.5 mm로 급증한다. 뒷바퀴도 지나는 위치에서 증가한다. 크기는 눈에 보이는 웅덩이와 맞는다.
2. **평지 130–155 km/h:** wetness / water 10 / 20 %에서 0.75–0.89 mm, 100 / 100 %에서 1.68–1.87 mm이다(평지 = wetness 수막).
3. **wetness 0, water 100 %:** 노면이 마르며 0으로 수렴한다(주변 팩 포함). 웅덩이를 밟는 순간에만 pack max가 1.8 mm로 짧게 튄다.
4. **리플레이:** 라이브와 같은 값이다(자기 차, AI 모두).

- **결론:** waterThickness = 노면 수막(wetness) + 접지점 웅덩이 깊이이다. 모든 차량과 리플레이에서 유효하다. → spray 원천으로 채택한다.
- **현재 모델의 결함(스크린샷 4):** wetness 0 / water 100 %(마른 노면)에서도 전역 max(water, wetness) = 1이라 팩 spray가 최대로 계산되어 굵은 줄기가 쏟아졌다.

## 5. PUD-2 구현 (spray.lua)
- **미세 spray:** 차량 i의 기여 k_i = 속도 법칙 × 횡 / 거리 감쇠 × (h̄_i / hRef)이다.
  - h̄_i는 그 차 4바퀴 waterThickness 평균을 τ = 0.3 s로 평활한 값이다(spray 구름의 지속).
  - hRef = 1.8 mm는 젖은 노면 전체의 수막(wetness 100 % 실측)이고, LWC0 보정점이다. 공급은 h에 선형이다(타이어가 만나는 물 Q = h b V, Koppa).
- **탄도 splash(1–4 mm):** 같은 식에 순간값 h_i / hRef를 쓴다 → 앞차가 웅덩이를 밟는 순간의 버스트가 된다.
- **자기 앞바퀴:**
  - 앞바퀴 h의 느린 기준(τ 2 s, 노면 수막) 위 초과분 / hRef = 웅덩이 초과(selfPuddle)이다.
  - splashSelfK(0.3, 웅덩이 레퍼런스로 보정 예정) × min(V / 20, 1)만큼 근거리 splash에 더한다.
  - spraySelf(구름)는 자기 앞바퀴 h를 쓴다.
- **유지:** 전역 경로는 토글 off일 때와 road override(M-REF3)가 켜졌을 때 쓴다.
- **UI:** 'Spray source = each car's wheel water', 'Own puddle excess'
- **CSV:** selfPuddle, wheelMode
- **비용:** 차량당 바퀴 4개 필드 읽기, 차량 인덱스별 숫자 1개(한 번 할당). 새 패스 / 텍스처가 없다.
- **측정 조건 갱신:** 노면은 이제 CSP 노면 그대로(레퍼런스 대응 wetness 10–15 %, water 30–40 %)를 쓴다. 'Fix road water / wetness'는 끈다. 켜면 전역 경로가 된다.

## 6. PUD-2 결과 (사용자) → PUD-3
- **확인:**
  1. intensity 0 / wetness 0: 물튐 없음(정상)
  2. intensity 0 / wetness 1(250 km/h): 정상적으로 튐
  3. wetness 0 / water 1: 평소 없음. 앞차 바퀴에 CSP 물튐 연기가 난 직후에만 튐(측정 약 0.4 mm)
- **문제 A(경로 지연):**
  - 앞차가 오른쪽 바퀴로 웅덩이를 깊게 밟았다(> 2 mm). 내 차는 뒤늦게 그 경로로 들어갔다.
  - 일직선 판정(내 시선 방향의 앞차, 현재 바퀴 값)으로는 정렬된 시점에 앞차의 값이 이미 0이라 맞지 않았다. 현실에서는 그 경로 위에 아직 떠 있는 물보라를 맞는다.
- **문제 B:** 자기 앞바퀴 웅덩이 splash가 레퍼런스보다 훨씬 적었다(빨간 표시 약 3개 vs 레퍼런스 수십 개).

### PUD-3 구현 (spray.lua)
- **경로 위 spray:**
  - 차량마다 경로 이력을 둔다(링 버퍼 64점, 2 m 간격 = 128 m ≥ sprayMaxM). 각 점은 그 순간의 속도항 sv와 직전 구간에서 만난 바퀴 물을 담는다. 미세 spray는 구간 평균, splash는 구간 최대를 쓴다. 2 m보다 짧은 웅덩이도 놓치지 않는다.
  - 헬멧 위치에서 가장 가까운 경로 구간까지의 횡거리²와, 그 점 이후 차가 달린 경로 길이 s로 기여를 계산한다. 폭 법칙(1.5 + 0.08 s), 거리 감쇠(25 m / 6 m)는 기존과 같다.
  - 차량의 진행 방향 뒤쪽에서만 기여한다(타이어는 앞으로 던지지 않는다).
  - **일직선 추종에서는 기존 시선 모델과 수치가 같다**(`docs/tools/rainfx2_spray_path_test.lua`: 0.5365 = 0.5365).
  - 경로 밖 웅덩이 시나리오(앞차 20 m 앞, x = 3 m 웅덩이 2.5 mm, 내가 나중에 진입)에서 spray와 splash를 받는 것을 확인했다.
  - 50 m 이상 순간 이동(리플레이 점프)이면 이력을 초기화한다.
- **자기 앞바퀴 splash:** splashSelfK 0.3 → 3.0(×10). 레퍼런스와 같은 구도에서 다시 확인한다.
- **비용(지침):**
  - 차량당 매 프레임 O(1) 기록, 120 m 안의 차량만 최대 64구간 최근접 탐색(곱셈 몇 개)
  - 테이블은 차량 인덱스별로 한 번만 만든다. 프레임당 할당이 없다.
  - 12대 기준 약 800구간 / 프레임(LuaJIT, 수 µs–수십 µs)
  - 새 GPU 작업이 없다.
- **토글:** p.sprayPath(false = PUD-2 시선 방식). 노면 override가 켜지면 전역 경로를 쓴다.
