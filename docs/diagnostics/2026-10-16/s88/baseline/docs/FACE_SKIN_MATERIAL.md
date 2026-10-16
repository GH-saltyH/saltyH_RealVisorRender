# 얼굴 재질: 약한 땀 광택 v1

## 결과물

위치: `ModelWorks/_2_blender_f1-helmet-lando_2025championWinner/texture/`

- `Driver_face_HQ_txMaps_skin_sweat_v1.png` / `.dds`: RGB 재질 데이터
- `Driver_face_HQ_txNormal_skin_sweat_DX_v1.png` / `.dds`: 게임용 tangent-space 노멀
- `Driver_face_HQ_txNormal_skin_sweat_GL_v1.png`: Blender 비교용 녹색 방향 반전 노멀
- `Driver_face_HQ_skin_sweat_v1.material.ini`: 새 모델의 ksEditor 재질 블록에 복사할 템플릿
- `Driver_face_HQ_skin_sweat_v1.json`: 원본 SHA-256, 생성 설정, 검증 결과와 파일 해시
- `Driver_face_HQ_skin_sweat_v1_preview.jpg`: RGB 및 채널별 미리보기

원본 `Driver_face_HQ_diff.png`의 **4096×2048** 픽셀 좌표를 그대로 사용했다. 리사이즈, UV 이동, AI 얼굴 재생성은 없다. 앞서 built-in imagegen으로 만든 초안은 최종 데이터에 사용하지 않았다. 최종 맵은 사용자가 승인한 Python 수치 처리로 제작했다. 이전 KN5, FBX.ini 및 현재 런타임 재질 값은 변경하지 않았다.

## 채널 의미

`ksPerPixelMultiMap`은 PBR ORM 맵을 사용하지 않는다.

| txMaps 채널 | 역할 | v1 설정 |
|---|---|---|
| R | `ksSpecular`의 강도 배율 | 건조한 피부 64, 코끝 약 145 |
| G | `ksSpecularEXP`의 배율: 높으면 하이라이트가 좁아짐 | 건조 피부 55, 코끝 약 165 |
| B | 환경 반사의 배율 | 피부 4, 코끝 10, 전체 최대 12 이하 |

값은 0–255 정수 데이터이며 감마 보정을 하지 않는다. **G는 roughness가 아니다.** 눈썹·콧구멍의 반사는 줄이고, 입술은 중간 정도로 설정했다. 눈은 별도 각막 재질이 아닌 얼굴 디퓨즈의 일부이므로 강한 거울 반사를 추가하지 않았다. 사진의 어두운 조명을 그대로 재질 값으로 변환하지 않았다.

근거: 저장소에 있는 CSP 공식 재구성 소스 `acc-shaders-master/recreated/include_new/base/utils_ps.fx`의 `LightingParams.applyTxMaps()` 및 `getReflParams()`. 각각 `specularValue *= R`, `specularExp = G * specularExp + 1`, `finalMult = B`를 사용한다. CSP의 별도 sunSpecular 항에는 B와 G도 관여한다. 이 프로파일에서는 그 추가 항을 0으로 설정한다.

[CSP 셰이더 소스](https://gitlab.com/ac-custom-shaders-patch/public/acc-shaders/-/blob/master/recreated/include_new/base/utils_ps.fx)

## 네이티브 재질 시작값

| 속성 | 값 |
|---|---:|
| Shader | ksPerPixelMultiMap |
| ksAmbient | 0.08 |
| ksDiffuse | 0.25 |
| ksSpecular | 0.25 |
| ksSpecularEXP | 120 |
| fresnelC | 0.028 |
| fresnelEXP | 5 |
| fresnelMaxLevel | 0.04 |
| ksEmissive | 0 |
| nmObjectSpace | 0 |
| useDetail / isAdditive / alpha blend / alpha test | 0 |
| sunSpecular / sunSpecularEXP (CSP 추가 속성) | 0 |

`txDiffuse`는 원본 `Driver_face_HQ_diff.png`, `txNormal`은 DX DDS, `txMaps`는 txMaps DDS에 연결한다. 세부적인 모든 속성은 `.material.ini`에 있다. `MATERIAL_0`은 자리표시자이므로 **새 모델의 mtHQFACE 재질 번호에 맞춰** 블록을 옮긴다. 원본 FBX.ini 전체를 이 파일로 교체하지 않는다. `txDetail`은 기존 `NULL.dds`를 사용하며 `useDetail=0`이다.

예시로 건조 피부 (64,55)의 스펙 강도는 약 0.063, 지수는 약 26.9이며 코끝 (145,165)은 약 0.142, 78.6이다. 이 값은 셰이더 입력 단계 계산이다. CSP의 조명·감마 처리와 시선각 때문에 화면 밝기는 이 수치에 정비례하지 않는다. B를 낮게 유지해 얼굴 전체가 환경을 거울처럼 반사하는 효과를 억제했다.

얼굴 부위와 땀 상태에 따라 표면 반사가 달라진다는 측정 연구를 참고했다. **위 ks 값은 해당 연구의 측정값을 직접 변환한 것이 아니라 이 텍스처용 초기 튜닝값**이다. 단일 디퓨즈로 실제 피부 BRDF를 측정할 수는 없다. 네이티브 셰이더는 피부의 실제 subsurface scattering을 재현하지 않으며 원본에 포함된 사진 명암도 유지된다.

[Weyrich, Acquisition of Human Faces Using a Measurement-Based Skin Reflectance Model, 2006, 10장](https://cgl.ethz.ch/Downloads/Publications/Dissertations/Wey06.pdf)

## 노멀 제작과 방향

- 큰 코·볼·눈구멍의 형태는 새 메쉬가 담당한다.
- 원본 명도의 1.3–6픽셀 대역만 추출해 모공·가는 주름의 약한 미세 요철을 만든다. 코와 이마에서는 요철을 줄인다.
- RGB 벡터를 정규화하고, 섬 외곽은 중립 `(128,128,255)`로 부드럽게 전환한다. 배경의 검정을 깊은 홈으로 만들지 않는다.
- 노멀은 디퓨즈에서 추정한 미세 요철이다. 일부 색소·촬영 질감이 남을 수 있으며 실제 스캔한 높이 데이터는 아니다.
- 게임에는 **DX**를 우선 사용한다. Blender Normal Map 노드에는 **GL** 파일을 `Non-Color`, Strength 1.0으로 연결한다. 이미 파일 자체의 요철을 약하게 만들었다.
- 새 메쉬의 UV 미러링, 탄젠트 생성 방식에 따라 최종 녹색 방향은 실기 확인이 필요하다. 모공이 솟아 보이면 반대 방향 파일로 비교한다. 매크로 얼굴 형태를 확인하는 테스트에는 사용하지 않는다.
- Blender에서 피부 Metallic은 0. Blender roughness 수치를 txMaps G로 그대로 복사하지 않는다.

## 적용·튜닝 순서

1. 새 2:1 UV가 원본 디퓨즈와 맞는지 확인하고 위 슬롯을 지정해 KN5를 다시 내보낸다. 새 UV에 맞는 탄젠트도 함께 재생성한다.
2. 우선 직접 보이는 얼굴에서 태양과 실내 조명 아래의 코끝·이마 광택을 확인한다.
3. 번들거림이 강하면 `ksSpecular`를 0.25 → 0.18로 낮춘다. 하이라이트가 너무 좁으면 `ksSpecularEXP`를 120 → 80으로 낮춘다. 이는 광학 반사 gain과 별개이다.
4. 코끝만 약하면 생성 스크립트의 코 영역 R/G 목표를 조절한다. 얼굴 전체 스펙 강도나 발광을 올려 보정하지 않는다.
5. 새 KN5 적용 후 형상/BVH와 재질 추출을 다시 수행하고 광학 캐시를 rebake한다. 이전 메쉬의 적중점·UV·재질 캐시는 재사용하지 않는다. 텍스처 제작만으로 기존 Final 합성 문제가 해결됐다고 판단하지 않는다.

## 포맷과 검증

PNG는 RGB8, DDS는 **비압축 RGBA8 UNORM, alpha=255, 13단계 전체 MIP**이다. 모든 채널은 데이터 값으로 저장한다. 노멀 MIP는 벡터를 평균낸 뒤 재정규화한다. 큰 MIP에서 조명 경계를 텍스처 그림자로 유지하지 않는다.

DDS 한 장은 약 **42.7 MiB**, 두 장은 약 **85.3 MiB**의 텍스처 데이터다. 얕은 노멀과 낮은 B 값을 보존하기 위해 BC 압축은 하지 않았다. 실제 VRAM 추가량은 기존 텍스처와 엔진 관리에 따라 다르다. 압축 배포가 필요하면 노멀의 미세 기울기와 UV 경계를 비교한 뒤 별도 버전을 만든다.

생성 시 검증: 원본 해시 불변, PNG 크기·픽셀 보존, DDS 헤더/길이/MIP 수/불투명 알파, DDS와 PNG의 베이스 레벨 픽셀 일치, 노멀 벡터 길이 오차, 중립 패딩, B 범위. 게임 및 새 KN5에 적용한 렌더 검증은 아직 수행하지 않았다.

재생성: Pillow와 NumPy가 있는 Python으로 `docs/tools/build_face_skin_textures.py` 실행. 다른 시안은 `--version v2` 등으로 별도 저장한다. 영역 마스크는 이 원본에 맞춘 값이므로 다른 UV 배치에는 다시 맞춰야 한다.
