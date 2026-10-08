# E1 3단계: 실제 하우징 삼각형 교차 검증

## 최신 방향: 캡처 깊이 경로 재평가

사용자 요청에 따라 실제 기하 경로와 BVH 데이터는 보존하고 기본 선택만 OFF로
돌렸다. 아래 실제 기하 검증 설정은 해당 체크박스를 ON할 때의 비교용 기록이다.
기존의 체커 휘어짐 피드백은 광학 경로 해석을 포함해 다시 평가한다.
개선 불가능하거나 기존 경로가 실패했다고 확정하지 않는다.

재평가 설정:

- `Primary actual housing geometry (validation)`: OFF.
- `Primary near-field depth parallax`: ON.
- `Primary trace range`: 1.50 m. 최근 스크린샷은 0.10 m이므로 같은 조건이 아니다.
- 우선 Source 2 / Primary 3: 체커 경로 확인. 이 진단은 MIP 0을 사용한다.
- Source 0 / Primary 3: 기존 lit 소스가 바이저에도 나타나는지 확인.
- lit 상태에서 MIP 0→2→4: 선명도 변화와 깊이 경계의 번짐을 구분한다.
- 카메라를 조금씩 이동하며 반사상의 이동·휘어짐이 연속적인지 확인.
  곡면 반사와 UV 섬 경계의 변화 자체를 오류로 판정하지 않는다.
- Source offset/FOV는 한 비교 동안 고정하고 정면과 오른쪽 끝 시점을 비교한다.
- EXT와 다른 오버레이 유지, E1 OFF 복원을 확인한다.

새 기하 경로에서 체커/UV 미리보기는 보였지만 실제 바이저 출력은 어둡게
관찰됐다는 결과도 기록한다. 부위별 UV 색 차이는 독립 UV 섬과 소스 메쉬가
다르면 발생할 수 있으므로 그 자체로 오류는 아니다. 새 경로의 검은 출력
원인은 확정하지 않았으며, 이 상태로 lit 경로를 대체하지 않는다.

### 캡처 재평가 후 품질 수정

사용자 결과: parallax ON / 1.50 m에서 source checker는 미리보기에 보이나
Primary 3은 검게 보이고, final은 저품질·노이즈 있는 출력을 보였다.
빛의 양에 따른 선별은 잘 작동했다. 반사 범위는 source offset/FOV에 종속됐다.

Primary 3은 기존에 HDR 이미지를 0~1로 압축한 뒤 HDR 타깃에 그렸다.
lit image 진단은 원래 HDR로 표시하고, checker와 나머지 진단색은 메인 HDR의
평균 휘도에 맞춰 진단 밝기만 보정한다. Final의 게이트와 프레넬 수식은 유지한다.
메인 HDR은 진단 밝기 기준이며 반사 이미지로 사용하지 않는다.

소스 색상과 metric depth를 모두 384×256에서 768×512로 올렸다.
lit 색상 샘플은 투영 UV의 픽셀 풋프린트에 따라 MIP를 선택한다.
사용자 blur MIP는 최솟값이며 checker는 이전처럼 MIP 0이다.
이 수정은 단일 캡처의 가려진 표면/시야 밖을 복구하지 않는다.

재평가 항목:

1. 앱 스크립트를 다시 로드하고 geometry OFF, parallax ON, range 1.50 m 유지.
2. 동일 offset/FOV·카메라에서 Source 2 / Primary 3 체커가 검정 대신 보이는지.
3. Source 0 / Primary 3에서 source와 같은 재질의 형상이 구별되는지.
   이 모드는 프레넬·밝기 게이트를 제외한 image 진단이다.
4. Source 0 / Primary 0에서 MIP 0/2/4 비교: 미세 노이즈와 경계 계단,
   카메라 이동 시 깜빡임, 세부 질감과 번짐 정도를 각각 기록.
5. 기존 빛에 따른 선별, EXT 유지, E1 OFF 복원 확인.
6. 소스 픽셀 수가 4배이므로 같은 시점의 ON/OFF 프레임 시간도 비교.

전체 LuaJIT 및 수정된 primary FXC ps_5_0 /Ges /WX 통과.
게임에서 진단 밝기 개선과 화질·비용은 재평가 대기다.

## 현재 변경

단일 뒤쪽 캡처의 깊이 추적은 사용자 평가에서 미통과다. Source offset과
카메라 거리에 따라 영역이 바뀌고 재질이 늘어나는 현상이 반복되었다.
현재 기본 경로는 캡처 깊이 대신 실제 하우징 삼각형을 교차 검사한다.
기존 깊이 경로는 비교용으로만 남겨 두었다.

실제 INT 표면 위치·법선과 관찰 카메라에서 반사광선을 계산하고,
FRAME / RUBBER / FABRIC 각각의 로컬 삼각형 BVH에 교차시킨다.
각 메쉬의 실제 월드 역변환과 교차 삼각형의 독립 UV를 사용한다.
INT / EXT / COATING UV가 같은 위치라고 가정하지 않는다.

## 이번 테스트 설정

- `E1 surface output test`: OFF.
- `E1 internal primary reflection`: ON.
- `Primary actual housing geometry (validation)`: ON (새 기본값).
- 바이저 위치: 사용하던 정상 위치부터 시작. source offset 최대값으로 보정하지 않는다.
- 모델: `visor_lando_2025Champion_maxquality_diet.kn5`.
- Primary trace range: 우선 1.50 m 유지.

## 구체적 평가 목록

1. **Primary mode 6 교차**: 녹색=실제 하우징 교차, 빨강=미교차,
   파랑=탐색 예산 초과. 파랑이 넓게 나오면 해당 시점과 상태 문구를 전달한다.
   하우징이 없는 반사 방향은 빨강이어도 정상이며 전체를 녹색으로 채우는 것이 목표는 아니다.
2. **캡처 독립성**: 같은 카메라·바이저 위치에서 source offset 0.025→0.150,
   source FOV 76→150, depth parallax ON/OFF를 바꾼다.
   소스 미리보기는 변할 수 있지만 새 Primary 교차 영역은 변하면 안 된다.
3. **Source mode 2 / Primary mode 3 체커**: FRAME 빨강, RUBBER 녹색,
   FABRIC 파랑. 같은 시점에서 녹색 교차 영역에 재질별 체크가 나타나는지 확인한다.
   카메라 정면과 오른쪽 끝→왼쪽 시점을 각각 첨부한다.
4. **Primary mode 5 UV**: 교차한 하우징의 UV 변화 확인.
   서로 다른 소스 메쉬 사이의 UV 불연속은 허용된다. 같은 표면 안에서
   한 텍셀 색이 긴 띠로 늘어나는 현상이나 큰 점프가 있는지 확인한다.
5. **Source mode 0 / Primary mode 3 재질**: 프레임·패브릭 원본 diffuse와
   고무 회색이 구분되는지. 이번 출력은 albedo 진단이며 lit 반사광이 아니다.
6. **카메라·바이저 이동**: 정상 위치에서 조금씩 이동할 때 교차 위치가
   연속적으로 변하는지. 실제 기하 관계가 바뀌므로 영역 변화 자체는 정상이다.
   source offset 변경과 실제 바이저 이동은 별도로 비교한다.
7. **기존 오버레이**: 하우징, INT 블러/굴절, EXT 밴드, 물방울 유지와
   E1 OFF 후 복원 확인. E1은 INT 뒤, EXT 앞에서 깊이 ReadOnly로 합성한다.
8. **비용**: 동일 환경·카메라에서 E1 ON/OFF의 FPS 또는 ms를 기록한다.
   현재 256픽셀 너비 진단 패스이므로 경계 계단이 있을 수 있다.

상태가 `Geometry error`, `model mismatch`, `requires one mesh`,
`Missing world transform`이면 문구와 전체 화면을 전달한다.
API 성공은 게임 출력 성공을 의미하지 않는다.

## 범위와 제한

Mode 1=교차 커버리지, 2=프레넬 진단, 3=체커/재질, 5=소스 UV, 6=교차 상태.
Mode 0 최종 합성과 Mode 4 밝기 게이트는 이 검증 경로에서 차단했다.
먼저 형상을 확정하고 개구부/내부 조명, 블러, 상대 노출, 고스트를 연결한다.
원본 재질 노멀·스페큘러·지역 조명은 이번 출력에 포함되지 않는다.

BVH 데이터는 위 KN5에서 생성했다. 같은 파일명을 유지하면서 모델을 수정해도
데이터를 재생성해야 한다. 런타임은 모델 경로를 검사하며 파일 해시를 검사하지 않는다.
생성 스크립트: `docs/tools/build_e1_housing_bvh.py` (Python + NumPy).
메타데이터와 원본 SHA256: `texture/GLASS/E1_GEOMETRY/manifest.json`.

## 로컬 검증

- 전체 LuaJIT 문법 검사 통과.
- 실제 교차 HLSL: FXC ps_5_0 /Ges /WX 통과.
- 메쉬별 24개, 총 72개 광선: BVH 최근접 교차와 모든 원본 삼각형 직접 검사의
  거리가 2 µm 이내에서 일치. UV 값 유한성 확인.
- 검사 광선의 최대 BVH 노드 방문 153개 (메쉬당 예산 1024개).
- 게임 출력, GPU 비용, 모든 관찰 위치의 커버리지는 사용자 평가 대기.

## EXT 가림 회귀 후 수정

사용자 평가: 실제 기하 ON / Primary 6에서 EXT 효과가 가려지고 진단 출력이
보이지 않았다. 별도 GeometryShot update가 INT draw 중 실행되는 구조를 발견했다.
캡처는 onSceneReady로 이동하고 INT draw는 준비된 텍스처 합성만 수행하도록 수정했다.
합성 좌표는 현재 렌더 타깃의 실제 크기로 정규화한다.
Lua mock에서 캡처 실행 단계, 합성 중 추가 캡처 없음, draw 실패 후 메쉬 표시와
렌더 상태 복원, 타깃 크기 적용, final 모드 차단을 확인했다. 엔진 내 복원은 재평가 필요다.

다음 평가: 같은 설정에서 EXT 유지 여부와 새 `Actual geometry output before INT composite`
미리보기의 색을 확인한다. 미리보기 자체가 검정이면 기하 캡처 단계 문제이며,
미리보기는 정상인데 INT만 비면 합성 단계 문제로 좁힐 수 있다.

기존 캡처 깊이 경로의 지저분한 출력은 개선 불가능하다고 확정하지 않았다.
깊이 불연속, 교차 오차, 투영 왜곡과 단일 캡처에 없는 표면은 구분해서 평가해야 한다.
BVH 경로는 좌표/교차 검증을 위한 비교 경로이며, 실제 lit 소스 결과를 아직 대체하지 않는다.

## 이번 사용자 재평가: 캡처와 INT 합성 확인

실제 기하 ON / Primary 6에서 EXT 효과가 유지됐다. 별도 기하 미리보기와
바이저에 녹색/빨강 출력이 나타났고, 바이저 출력은 반투명으로 합성됐다.
사용자는 이전 거리 의존성 대신 바이저 표면에 고정된 모습을 관찰했다.
첨부 미리보기에는 중앙 위쪽 빨강과 주변 녹색이 보이며 뚜렷한 파랑은 없다.
이 결과는 렌더 경로 검증 통과이며 반사 위치·재질 UV 정확성 검증은 아직 아니다.

다음은 같은 geometry ON 상태에서 Source 2 / Primary 3 체커,
Primary 5 소스 UV, Source 0 / Primary 3 재질을 정면·측면에서 비교한다.
기하 경로 UI에는 기존 캡처 깊이 경로의 다른 색상 범례를 표시하지 않도록 정리했다.


## 다음 품질 단계: 가변 해상도와 하우징 멀티맵 조명

사용자 확인: 체커와 lit 재질 모두 바이저에 나타나며 MIP 변화는 자연스럽다.
768×512 증가에 관찰 가능한 FPS 차이는 없었으나 윤곽·재질 디테일은 부족하다.
상은 source offset 0.150 근처에서 확인된다. 이 값의 의존성은 해결되지 않았다.

Source quality를 0/1/2/3으로 선택해 384×256 / 768×512 / 1536×1024 /
3072×2048을 비교한다. 새 기본값은 2다. 변경 시 색상·metric depth를 함께
재할당한다. 소스 크기와 평균 휘도 MIP는 실제 텍스처 차원으로 계산한다.
미리보기 UI는 축소되므로 디테일은 실제 바이저 출력에서 비교해야 한다.

하우징에는 레퍼런스 계산에 맞춘 비교 경로를 추가했다.
`Housing: reference multimap lighting` ON이 새 기본값이며 OFF는 기존 재질 모델이다.
FRAME / RUBBER / FABRIC의 원래 독립 UV와 텍스처는 유지한다.

- R: 스페큘러 강도 곱.
- G: 기본 스페큘러 지수에 선형 곱 +1. 이전 gloss² 및 지수별 임의 증폭 제거.
- B: 환경 반사 프록시에 직접 곱. B=0인데 반사가 남던 최솟값 제거.
- direct diffuse: Lambert; direct specular: Blinn-Phong × N·L × shadow.
- 패브릭의 뒤쪽까지 켜지는 wrapped direct diffuse 제거.
- 패브릭 sheen은 선택 재질 확장으로 유지하며 direct 부분은 같은 그림자 적용.
- 하우징 diffuse/maps/normal의 반복 주소를 명시적으로 처리하여 음수 UV 타일
  경계의 clamp 영향을 줄임. 유리 효과의 샘플링은 기존 경로를 유지.

로컬 근거:
`acc-shaders-master/recreated/ksPerPixelMultiMap_emissive_ps.fx`,
`include_new/base/utils_ps.fx`의 LightingParams.applyTxMaps,
`include_new/ext_lighting_models/_include_ps.fx` 기본 reflectanceModel.
원본의 전체 조명을 이식한 것은 아니다. 기존 HDR/ambient/bounce와 주 카메라
shadow probe를 사용하며 내부 소스에는 해당 probe를 적용하지 않는다.
엔진 AO, 지역 조명, 내부 캡처용 공간별 그림자와 방향별 환경 반사는 미구현이다.

평가 순서:

1. reference lighting OFF, source quality 1→2→3, Source 0 / Primary 3,
   MIP 0에서 같은 카메라·offset 0.150·FOV로 윤곽/질감/계단/깜빡임 비교.
   MIP는 Texel 단위이므로 해상도별 같은 값이 같은 물리적 번짐을 뜻하지 않는다.
2. quality 2 고정, reference lighting ON/OFF: 화면 하우징과 source 프리뷰의
   러버·패브릭·프레임 명암을 각각 확인. 비스듬한 빛, 정면 빛, 반대 빛에서 비교.
3. Final의 기존 빛 선별과 MIP 반응, EXT/RainFX/INT 효과와 OFF 복원 확인.
4. quality 1/2/3의 동일 시점 프레임 시간 비교. 아직 비용 실측은 없다.

전체 LuaJIT, primary 및 공통 housing HLSL FXC ps_5_0 /Ges /WX 통과.
공통 HLSL BOM 없음 확인. 게임 화질과 재질 튜닝은 사용자 평가 대기.
