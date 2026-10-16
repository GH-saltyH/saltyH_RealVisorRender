# E1 복수 원점 캡처 실험 준비 보고

상태: 실험 A 구현 완료. 기본 OFF이며 기존 단일 소스와 비교할 수 있다. 자동 fallback/혼합인 실험 B는 실험 A의 게임 검증 후 진행한다.

## 이번 빌드 사용법

상향 원점/하향 시선 비교: `Source height above eye`를 +0.020m, `Source pitch (positive looks down)`을 +10도로 시작 후보로 사용한다. 두 값은 단일/복수 소스 모두에 적용하며 중앙/좌/우는 동일한 높이와 피치를 사용한다. 높이는 헬멧 로컬 +Y, 양의 피치는 -Y를 향한 기울기이다. colour와 metric depth의 원점/방향/up은 일치시킨다. 기본 0/0은 기존 시점을 유지하며, 최적값과 찢어짐 개선 여부는 게임에서 확인해야 한다. 기존 material settings 저장 경로에 포함된다.

1. 머티리얼 에디터의 E1 stage 2에서 `E1 multiview experiment (manual selection)`을 ON한다.
2. 기준 시점에서 `Reset source anchor from current eye`를 누른다. 눈 위치를 헬멧 로컬 좌표로 저장하며 기존 offset을 그 위치에서 전방으로 적용한다. 이후 원점은 헬멧을 따라 움직인다.
3. 중앙 quality 2 / side quality 1 / lateral spacing 0.030m로 시작한다. Source slot 0=중앙, 1=로컬 -X, 2=로컬 +X이다. 좌/우 이름이 모델의 실제 축 방향과 일치하는지는 게임에서 확인한다.
4. 각 슬롯 선택이 소스 preview와 primary reflection 모두를 바꾼다. 세 슬롯의 현재 프레임 번호, ready/unavailable, 해상도와 오류를 표시한다. lit/aperture/checker/metric depth에 적용된다.
5. 우측면의 누락된 면과 찢어짐을 세 슬롯에서 비교한다. 보조 quality 1의 곡선 단절이 심하면 side quality 2로 비교한다. OFF는 기존 메인 카메라 종속 원점 경로로 돌아가고 보조 자원을 해제한다.
6. 비교 중 offset/FOV/범위/샘플 예산/gate/blur를 고정한다. 설정은 기존 `Apply & save all materials`로 저장한다. 최신 빌드는 anchor의 헬멧 로컬 X/Y/Z도 INI에 저장하고 복원한다. 모델 좌표/규모가 변경되면 다시 설정한다.

세 소스는 매 프레임 모두 캡처하며 선택한 한 소스만 추적한다. 따라서 이번 실험의 비용 증가는 주로 추가 캡처에서 발생한다. 자동 fallback 추적 비용은 아직 포함하지 않는다. 게임 성능과 보조 캡처의 실제 표면 복구 효과는 미검증이다.

검증: `docs/tools/check_e1_multiview.py`에서 LuaJIT 전체 구문, 기존 KN5 가시성/캡처 보호, 3슬롯 독립 갱신, 헬멧 anchor, 수동 선택, 동일 프레임 번호, 실패 슬롯 정리, anchor reset, OFF/전체 dispose, 실제 depth draw의 슬롯별 행렬/mesh ID와 가시성 복원을 검사했다.

## 확인된 사실

- 사용자: reflection-space 필터 추가 후 관찰 가능한 FPS 비용 증가 없음.
- 사용자: 우측 시점에서 offset 증가 시 히트 영역이 넓어지지만 가장자리가 찢어짐. 감소 시 부드러워지지만 반사 범위가 줄어듦.
- 현재 `e1SourceUpdate` 원점은 `sim.cameraPosition + helmetForward * offset`. 방향은 헬멧 축을 사용하지만 원점은 메인 카메라에 종속된다.
- 색상과 metric depth는 같은 원점/FOV로 캡처한다. 깊이는 한 픽셀의 최근접 면 하나만 표현한다.
- native capture는 등록된 복제 KN5의 허용 목록을 쓰며 각 캡처 전후 가시성을 복구한다. 복수 샷이 동일한 등록 모델을 공유하는 설계가 가능하다. 실제 엔진에서 연속 샷 갱신은 검증이 필요하다.
- 기존 BVH 경로는 진단용이며 lit/final이 연결되지 않았다. 새 KN5에 대한 데이터 재생성도 필요하다.
- 최근 사진은 FOV 108도, sample budget 62, trace range 0.31m이다. 이전 quality 2 / budget 32 측정과 직접 비용 비교할 조건은 아니다.

원인 가설: 단일 시점의 가림과 깊이 불연속에 의한 오교차/미스. 현재 사진만으로 모든 찢어짐을 이것으로 확정하지 않는다. 거리 상한, depth와 native colour의 cull/alpha 차이, 같은 메쉬 안의 불연속도 함께 점검한다.

## 실험 A: 세 원점과 수동 선택

먼저 자동 전환 없이 중앙/좌/우 각각을 독립적으로 출력해 보조 캡처가 실제 누락된 표면을 제공하는지 검증한다.

- 중앙 원점은 기준 포즈의 기존 캡처 원점을 헬멧 로컬 좌표로 변환하여 보관한다. 이후 현재 헬멧 행렬로 월드 위치를 계산한다. 시선 회전/메인 카메라 이동이 소스 원점을 임의로 바꾸지 않게 한다.
- 좌/우 원점은 중앙에서 헬멧 로컬 좌우로 각각 30mm 이동한 값을 시작 후보로 사용한다. 15/30/45mm 비교가 필요하며 최적값으로 확정하지 않는다.
- 초기에는 세 샷의 방향과 FOV를 동일하게 유지해 원점 이동 효과만 비교한다. 원점이 메쉬 내부에 들어가는 경우에는 배치부터 수정한다.
- 각 슬롯은 native HDR colour, metric depth+mesh ID, view/projection, origin, 해상도, frame ID, ready/error를 독립적으로 갖는다.
- 캡처 허용 대상: BODY_FRAME / BODY_GLASSLINE / BODY_FABRIC / DRIVER_FACE / DRIVER_BALAKLAVA. 메인 카메라의 얼굴 숨김과 KN5 머티리얼을 유지한다.
- lit/aperture/checker/metric depth 모두 슬롯별로 확인한다. depth 콜백은 현재 전역 source.view 대신 해당 슬롯의 view를 받아야 한다.
- UI: multiview OFF/ON, slot centre/left/right, lateral spacing, anchor reset, 슬롯별 현재 프레임 상태. 기존 offset/FOV와 독립성을 명확히 표시한다.

첫 승인 조건: 우측면에서 중앙이 놓친 러버·패브릭·얼굴 중 적어도 하나를 보조 슬롯이 온전하게 캡처하고 추적해야 한다. 이것이 실패하면 자동 소스 선택 구현으로 진행하지 않는다.

## 실험 B: 조건부 보조 추적

실험 A를 통과한 뒤 중앙을 주 소스로 유지하고 낮은 신뢰도의 픽셀에만 좌/우 보조 소스를 적용한다.

1. 주 소스로 기존 32샘플 추적을 실행한다.
2. 미스, 프러스텀 경계, 큰 깊이 변화 또는 큰 최종 잔차에서 보조 추적을 허용한다. 현재 녹색 히트라도 잘못된 면일 수 있으므로 히트 여부만으로 신뢰도를 결정하지 않는다.
3. 광선 방향과 캡처 범위로 적합한 보조 슬롯 하나를 선택한다. 방향만으로 가림 여부를 알 수 없으므로 이 선택은 후보 순위이다.
4. 보조 슬롯에서 얻은 점을 공통 헬멧 좌표로 복원한다. 양의 광선 거리, 광선과의 위치 오차, mesh ID, 깊이 잔차로 승인한다. 거리 상한 내의 유효 후보 중 최근접 교차를 우선한다.
5. 두 후보가 같은 mesh ID와 가까운 위치를 가리킬 때만 색상을 부드럽게 전환한다. 다른 표면은 혼합하지 않는다. 같은 ID라도 위치가 다르면 같은 히트로 취급하지 않는다.
6. 기존 현재 프레임 reflection-space resolve에 연결한다. 과거 프레임 누적으로 캡처 누락을 채우지 않는다.

진단: 선택 슬롯 색상, fallback 사용 영역, hit/miss, 깊이 잔차, 두 캡처의 위치 불일치, 원점/프러스텀. mesh ID 진단은 기존 trace 녹색과 별도 표시한다.

보조 추적 예산은 초기 후보 16샘플이며 품질 비교 후 결정한다. 32+16은 상한 후보일 뿐, 미스율이 높으면 비용이 크게 증가한다. 세 소스를 모든 픽셀에서 각각 32샘플 추적하는 구성을 기본으로 삼지 않는다.

## 비용과 수명주기

- capture colour/depth는 모두 현재 프레임에서 갱신한다. 시간 분할 갱신은 우선 제외해 이전 프레임 데이터에 의한 오차를 분리한다.
- 모델은 슬롯마다 새 KN5를 로드하지 않고 등록된 하나의 capture reference를 공유한다. 각 GeometryShot의 텍스처/행렬은 독립적이다.
- 초기 품질은 중앙 quality 2, 보조 quality 1로 시작한다. 보조 quality 1의 곡선 단절이 재현되면 보조도 quality 2로 높여 비교한다.
- R16G16B16A16 colour full MIP + metric colour + 두 D32 depth 기준, quality 2 한 슬롯 약 40MiB, quality 1 약 10MiB의 텍스처 예산 추정이다. 실제 할당·정렬·엔진 임시 자원은 추가될 수 있다. 중앙 Q2+보조 Q1 두 개는 약 60MiB, 모두 Q2는 약 120MiB이다.
- FPS는 기존 사용자 측정으로 예측하지 않는다. 캡처 횟수가 세 배라는 사실이 전체 비용 세 배를 뜻하지 않는다.
- 한 슬롯 실패 시 그 프레임에서 제외한다. 모든 슬롯 실패 시 반사를 출력하지 않는다. 리사이즈/품질 변경/KN5 교체 시 슬롯별 dispose/recreate. 반사 OFF 시 보조 자원 해제.
- 기존 nativeCaptureActive 보호와 매 캡처 후 숨김을 유지한다. 새 슬롯 준비 시에도 엔진 transform 갱신을 위한 update 끝의 등록 모델 준비를 유지한다.

## 비교 절차

같은 차량 위치·조명·시선 경로를 사용한다. gain/threshold/MIP/blur/trace scale은 비교 중 고정한다.

1. 기존 단일 소스: offset 0.091 / 0.150, FOV 108, quality 2, budget 32를 비교한다.
2. range 0.31 / 1.50m를 별도로 비교하여 거리 제한으로 인한 미스를 분리한다. 1.50m가 무조건 정답이라고 가정하지 않는다.
3. 헬멧 고정 중앙 소스만 사용해 메인 카메라 종속성 영향을 확인한다.
4. 좌/우를 각각 수동 선택해 누락 개선과 새 깊이 불연속을 확인한다.
5. 보조 캡처 ON, fallback OFF로 캡처 자체 비용을 측정한다.
6. fallback ON으로 추적 비용과 히트 개선을 측정한다.
7. 정면→우측→정면, 상하 회전과 카메라 위치 이동, 낮 태양/밤 국소 조명을 확인한다. 선택 소스 변경 시 이중상·밝기 점프·얼굴 노출을 검사한다.

기록은 FPS와 ms/frame을 함께 남긴다. 관찰 대상은 범위 증가, 실루엣 찢어짐, 메쉬별 누락, 전환 팝핑, fallback 비율, 메모리이다.

## 다음 판단

### 실험 A 사용자 피드백

현재 후속 구현: [5종 기하 교차 진단](E1_FIVE_MESH_GEOMETRY.md)을 연결하고 활성 KN5 원본에서 BVH를 재생성했다. source 독립 기하 진단 단계이며 native colour 재투영은 아직 연결하지 않았다.

우측 카메라에서 슬롯 2가 누락된 면을 제공함을 확인했다. 그러나 원점/offset에 따라 각 시점에서 잘림과 찢어짐이 달라져 고정된 소스 배치만으로 다양한 카메라 위치/FOV를 만족하기 어렵다는 평가이다. 관측 범위 보완은 확인됐지만 범용 품질 해결은 확인되지 않았다.

다음 우선순위는 자동 fallback보다 실제 삼각형 교차 검증이다. 현존 `e1HousingGeometry.hlsl`은 세 하우징 메쉬의 BVH만 추적하며 face/balaclava가 없고 lit/final이 연결되지 않았다. 기존 packed BVH는 새 KN5에 맞춰 재생성해야 한다. 먼저 현재 다섯 메쉬의 hit position/distance/mesh ID를 검증하고, offset/FOV를 변경해도 기하 히트가 변하지 않는지 확인한다. 그 후 같은 히트 위치에 대한 native colour를 복수 캡처에서 depth/ID 일치로 선택한다. 캡처 실패와 실제 geometry miss를 진단에서 구분한다.

이 구조에서도 어느 캡처에도 보이지 않는 점의 native 색상은 얻을 수 없다. 필요한 점의 관측률을 확인한 뒤 추가 원점/방향을 선정해야 하며, 고정된 세 캡처가 모든 시점에서 완전하다고 가정하지 않는다.

복수 캡처는 관측 가능한 표면을 늘리지만 실제 형상의 완전한 표현은 아니다. 같은 메쉬의 가림/깊이 불연속 때문에 여전히 잘못된 녹색 히트가 많다면 BVH 최근접 교차로 위치를 결정하는 단계로 넘어간다.

BVH 교차 후에도 native colour는 선택한 캡처에서 해당 점이 보이는지 depth 일치로 검사해야 한다. 보이지 않는 점의 색을 투영해 가져오면 앞에 있는 다른 표면의 색이 입혀진다. 네이티브 캡처의 specular/Fresnel은 캡처 시점 의존성이 있어 완전한 반사 시점 셰이딩과 동일하지 않다. 이를 해결하는 별도 라이팅 재구현은 사용자가 보류한 연구 범위에 속한다.

참고: 단일/다층 깊이 기반 추적의 표현 한계와 재투영은 NVIDIA의 [An Adaptive Acceleration Structure for Screen-space Ray Tracing](https://research.nvidia.com/sites/default/files/pubs/2015-08_An-Adaptive-Acceleration/AcceleratedSSRT_HPG15.pdf)에서 다룬다. 이 실험은 해당 알고리즘을 그대로 구현하는 계획이 아니다.
