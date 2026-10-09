# E1 BVH 교차점의 네이티브 색상 재투영

## 현재 구현

5종 BVH가 반사 위치를 결정하고, 기존 native colour/depth 캡처가 해당 위치의 색상을 제공한다. 단일 소스일 때 중앙 후보 하나, multiview일 때 현재 프레임의 중앙/좌/우 후보를 검사한다. manual source slot은 preview 선택이며 BVH colour 경로에서는 세 슬롯 모두를 사용한다.

- 교차점은 `pin.PosC + reflectedRay * hitDistance`로 계산한다. 이 값에 현재 eye와 각 capture origin의 차이를 더해 capture-relative 공간으로 옮기고 해당 view 회전/projection으로 투영한다.
- 각 소스의 bilinear 네 픽셀을 개별 검사한다. depth coverage, 5종 mesh ID, 교차점의 capture-view metric depth와의 잔차가 모두 통과한 tap만 colour에 기여한다.
- 허용 잔차 기본 0.003m. `Geometry colour depth tolerance`에서 0.001–0.010m로 비교한다. 큰 값은 관측률을 높일 수 있지만 같은 메쉬의 인접 면을 잘못 승인할 위험도 늘어난다.
- 색상은 MIP 0에서 검증된 tap만 보간한다. 원본 소스의 넓은 MIP가 다른 면의 색을 섞지 않게 한다. 이 경로에서 기존 source blur MIP는 적용하지 않으며 최종 화면 반사 공간에서 blur한다.
- 여러 캡처는 같은 BVH 점과 같은 mesh ID를 검증한 경우에만 support와 캡처 경계 여유에 따라 혼합한다. 단순히 서로 다른 교차 결과를 혼합하지 않는다. 슬롯 실패, 이전 프레임, checker 캡처는 colour 후보에서 제외한다.
- mode 0 final은 HDR colour, 기존 relative luminance gate, visor Fresnel, gain을 연결한다. 평균 휘도는 유효 colour 후보의 source MIP 평균을 동일한 가중치로 혼합한다.
- final 오프스크린 alpha는 앞 INT 표면 거리이며 합성에서 중복 뒷면을 제한한다. final RGB는 9탭 공간 필터 후 additive 합성한다. 과거 프레임 누적은 없다. raw image/진단은 final 필터를 거치지 않는다.

## 사용법

1. 스크립트 재로드. E1 primary와 `Primary actual geometry (five-mesh validation)` ON.
2. Source mode **0 lit**. Multiview ON이면 세 colour 소스를 사용한다. OFF이면 기존 한 소스만 사용한다.
3. Primary mode **9 colour coverage**를 먼저 확인한다:
   - 빨강: geometry miss
   - 주황: geometry hit, 유효 native colour 없음
   - 녹색: 검증된 native colour 있음
   - 파랑: BVH traversal 미완료
4. Primary mode **10 source**: 가장 높은 가중치의 소스를 중앙 빨강 / 좌 녹색 / 우 파랑으로 표시한다. 주황은 colour 없음. geometry miss는 빨강이므로 상태 구분은 mode 9와 함께 확인한다. 실제 출력 색상은 유효 소스들의 혼합이다.
5. Mode **3 image**는 검증된 raw HDR colour, **4 gate**는 luminance gate, **0 final**은 최종 반사이다. Source checker + mode 3은 기존 기하 체커를 유지한다. mode 6/7/8 기하 진단도 유지한다.
6. `Geometry colour output width` 기본 **512px**, 범위 128–1024. Colour 관련 모드에만 적용하며 기존 기하 진단은 256px 폭을 유지한다. `Primary reflection-space blur` 기본 1.5px를 final에 적용한다. `Primary reflection trace scale`과 sample budget은 기존 captured-depth 경로용이며 BVH 해상도/추적량을 조절하지 않는다.
7. offset/FOV/높이/pitch를 바꿀 때 기하 hit는 그대로이고 colour 관측률과 슬롯 기여는 달라질 수 있다. mode 9의 주황 영역을 관찰해 캡처 누락을 구분한다. 정면/우측 극단과 낮/밤 조명에서 image/final, 슬롯 전환 경계와 FPS를 확인한다.

새 설정도 기존 `Apply & save all materials` 저장 경로에 포함된다. 원본 KN5 네이티브 머티리얼은 변경하지 않는다.

## 한계 및 검증

### 하이라이트 튜닝 UI

BVH에서는 source blur MIP / trace sample budget / reflection trace scale / depth parallax를 표시하지 않는다. 이 값은 기존 capture-depth 경로에만 유지한다. Sharpness는 reflection-space blur, 해상도는 Geometry colour output width로 조절한다.

Mean luminance floor는 이미 `max(source mean, floor)`로 연결돼 있으나 source mean보다 낮으면 효과가 없었다. BVH의 HDR 조절 범위를 0.001–200으로 확장하고 자동 모드에서는 `Highlight reference minimum`, 고정 모드에서는 `Highlight fixed reference`로 표시한다. 새 `Highlight fixed HDR reference`를 ON하면 source 평균 대신 지정 HDR 휘도를 기준으로 q를 계산한다. relative threshold는 이 기준에 대한 배수이며 soft knee는 q 단위이다.

새 `Highlight baseline removal` 0–1은 final에서 `max(luminance-reference*threshold,0)/luminance`의 적용량을 조절한다. 0은 기존 출력, 1은 기준 이하의 배경 휘도 성분을 제거한다. RGB에 동일한 배수를 적용해 색 비율을 유지한다. 제거는 전체 밝기를 줄일 수 있어 gain을 함께 조절한다. HDR gain 범위는 BVH에서 0–100으로 확장했다. 새 옵션 기본값은 OFF / 0으로 기존 결과를 유지한다. Mode 3 raw는 gain/gate/removal 전, Mode 4는 gate, Mode 0은 전체 처리가 적용된다.

Final 버퍼 alpha는 INT 거리인데 이전 preview가 이를 투명도로 사용해 어둡게 표시했다. 이제 opaque canvas로 표시하고 HDR RGB를 공통 divisor로 압축한다. 이 preview는 수치적 HDR 밝기를 그대로 표시하는 화면이 아니며, 최종 게임 합성은 거리 alpha를 계속 사용한다.

튜닝 순서: Source lit / Primary 4에서 fixed reference와 threshold로 통과 영역을 확인한 뒤 Primary 0에서 baseline removal 및 gain을 조절한다. blur 0–0.5px로 필터 영향을 먼저 분리하고 이후 필요량을 늘린다. gate가 통과해도 raw Mode 3에 하이라이트가 없다면 네이티브 재질/조명 캡처 문제로 분리한다. 원본 캡처에 없는 하이라이트를 이 처리로 복원한다고 가정하지 않는다.

### 최신 사용자 검증과 수정

사용자: 반사 위치/깊이가 납득 가능했고, 외부 시점에서 전체 모델이 들어오도록 anchor를 잡았을 때 다양한 시점에서 잘림 없는 상을 확인했다. E1 전체 비용은 맑은 낮 약 6FPS, 국소 조명이 많은 맑은 밤 약 2FPS 감소로 보고됐다. 각 기준 FPS가 없으므로 이 차이만으로 밤의 GPU 시간 증가가 더 작다고 확정하지 않는다. 출력 폭 512 아래에서는 번짐의 품질 손실이 커 기본값 512를 유지한다.

갱신한 KN5 원본으로 BVH를 다시 구웠다. DRIVER_FACE는 2,004 vertices / 3,088 triangles / 1,023 nodes로 변경됐다. 나머지 4종의 triangle/node 수는 유지됐다. manifest SHA256도 현재 원본으로 갱신했다.

최초 로드 대응: 등록된 capture KN5가 생성된 프레임에 GeometryShot을 만들지 않고 script.update 끝의 nativeCapturePrepare를 거친 뒤 생성한다. 멀티뷰 anchor도 이 준비 이전에는 확정하지 않는다. 변경된 순서는 실제 게임 재로드 검증이 필요하다.

외부 시점 anchor는 이제 헬멧 로컬 X/Y/Z와 saved 플래그를 settings_mats.ini에 저장한다. 기존 버전은 anchor를 저장하지 않았으므로 업데이트 후 한 번 기존 외부 시점에서 Reset source anchor를 눌러 다시 잡는다. 이후 자동 저장 또는 Apply & save all materials로 저장하면 재로드/멀티뷰 토글 시 복원된다. 새 KN5가 helmet 좌표나 규모를 변경했다면 다시 보정한다.

Source Mode 1의 기존 aperture 전역 태양 방향 가중치를 native lit luminance 진단으로 교체했다. 국소 광원에 반응하는 실제 캡처 휘도를 보여주지만 개구부의 기하학적 광원 가시성을 계산하는 모드는 아니다. Legacy opening weight는 현재 native 색상에 적용하지 않는다.

네이티브 캡처 RGB와 final의 scalar gate/Fresnel/gain은 광원 색을 보존한다. 전역 sun 색을 다시 곱하면 국소 조명의 색이 왜곡될 수 있어 추가하지 않았다. Preview의 per-channel C/(1+C)는 강한 coloured highlight를 백색 쪽으로 압축하므로 공통 RGB divisor를 사용해 비율을 보존하도록 변경했다. 이 변경은 preview에만 적용하며 source HDR/final radiance는 그대로 유지한다. Final에서 낮은 채도가 남는다면 native 캡처 자체와 tone mapping 이후 결과를 비교해야 한다.

기하 교차는 단일 capture depth와 독립적이다. 모든 소스에서 가려진 점은 색상을 얻을 수 없으며 검증되지 않은 다른 면의 색을 채워 넣지 않는다. Colour/depth의 authored cull·alpha 차이로 관측 실패가 생길 수 있다. BVH는 양면 삼각형이며 alpha cutout을 추적하지 않는다. 네이티브 specular/Fresnel은 캡처 시점의 결과이므로 실제 반사 시점에서 재셰이딩한 것과 동일하지 않다.

FXC는 실제 geometry 및 INT composite 셰이더를 ps_5_0 /Ges /WX로 컴파일했다. 원본/BVH 140개 광선 비교가 유지된다. LuaJIT와 실제 runtime 함수 mock에서 5종 바인딩, final/checker 제한, 동일 프레임 native colour 선택, 실패/누락/이전 프레임 제외, single-source 복귀를 확인했다. 실제 게임의 colour 관측률·하이라이트·GPU 비용은 아직 미측정이다.
