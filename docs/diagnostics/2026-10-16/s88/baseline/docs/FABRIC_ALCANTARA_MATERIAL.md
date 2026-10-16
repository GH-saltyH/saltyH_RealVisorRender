# BODY_FABRIC 알칸타라 txMaps v1

## 결과물과 적용

`ModelWorks/_2_blender_f1-helmet-lando_2025championWinner/texture/`에 저장했다.

- **게임용:** `BODY_INT_FABRIC_2K_txMaps_alcantara_v1.dds`
- 편집 원본: 같은 이름의 `.png`
- 권장 ksEditor 재질: `BODY_INT_FABRIC_alcantara_v1.material.ini`
- UV 확인 마스크: `BODY_INT_FABRIC_2K_UV_alcantara_v1.png`
- 미리보기: `BODY_INT_FABRIC_alcantara_v1_preview.jpg`
- 입력 해시·설정·검증 기록: `BODY_INT_FABRIC_alcantara_v1.json`

새 모델의 `mtBODY_FABRIC` 재질에서 **txMaps 슬롯만 새 DDS로 지정**하면 맵을 사용할 수 있다. 디퓨즈와 노멀 슬롯은 첨부한 기존 파일을 사용한다. 더 차분한 광택으로 시작하려면 아래 권장 재질 값을 함께 적용한다. `.material.ini`의 `MATERIAL_0`은 자리표시자이며 실제 모델의 재질 번호에 맞춰 블록을 옮긴다. 기존 FBX.ini 전체를 이 파일로 덮어쓰지 않는다.

## 맵 제작 기준

원본 디퓨즈는 2048×2048 DXT5, 원본 노멀은 4096×4096 DXT5이다. 최종 txMaps는 **2048×2048 RGB8**이다. 기존의 수치 처리 승인에 따라 Pillow/NumPy로 제작했으며 AI 픽셀을 사용하지 않았다. 원본 DDS·KN5·현재 재질 설정은 변경하지 않았다.

기존 `visors/visor_lando_2025Champion_maxquality_diet_face.kn5`의 **BODY_FABRIC UV 삼각형을 직접 래스터화**했고, 첨부 노멀의 미세 패턴 구역에 겹쳐 일치하는 것을 확인했다. 저장된 V는 [-1,0]이므로 `V+1`로 DDS 좌표에 배치했다. 메쉬에 쓰이지 않는 방사형 스트레치 패딩을 섬유 패턴으로 사용하지 않는다. 최종 맵 패딩은 `(32,64,3)`이며 UV 경계에서도 이 값으로 변화를 부드럽게 줄여 검은 경계나 갑작스러운 광택 차이가 생기지 않도록 했다.

| 채널 | 네이티브 ksPerPixelMultiMap 의미 | v1 기준 |
|---|---|---|
| R | 스펙 강도 배율 | 기준 32, 낮은 강도의 섬유 변화 |
| G | 스펙 지수 배율, 높은 값일수록 좁은 하이라이트 | 기준 64, 낮은 지수의 넓은 광택 |
| B | 환경 반사 배율 | 기준 3, 아주 약한 반사 |

디퓨즈의 국소 미세 질감 및 완만한 결 변화를 사용했다. 노멀은 국소 RG 변화량으로 섬유의 흐트러짐을 참조한다. 노멀 방향 자체를 특정 광원에서의 밝기로 바꾸거나 사진의 전체 명암을 스펙 마스크에 복사하지 않았다. 섬유 변화가 큰 부분은 G를 약간 낮춰 하이라이트가 부드럽게 퍼지게 했다. 강한 땀·젖음이나 가죽 같은 작은 하이라이트는 추가하지 않았다.

채널 공식의 근거는 `acc-shaders-master/recreated/include_new/base/utils_ps.fx`의 `applyTxMaps()`와 `getReflParams()`이다. R/G/B는 PBR ORM 또는 roughness/metallic 채널이 아니다.

[CSP 셰이더 소스](https://gitlab.com/ac-custom-shaders-patch/public/acc-shaders/-/blob/master/recreated/include_new/base/utils_ps.fx)

## 권장 시작 프로파일

| 속성 | 값 |
|---|---:|
| Shader | ksPerPixelMultiMap |
| ksAmbient | 0.05 |
| ksDiffuse | 0.30 |
| ksSpecular | **0.35** |
| ksSpecularEXP | **40** |
| fresnelC | 0.02 |
| fresnelEXP | 3 |
| fresnelMaxLevel | 0.12 |
| nmObjectSpace | 0 |
| ksEmissive / isAdditive / useDetail | 0 |
| sunSpecular / sunSpecularEXP (CSP 추가 항) | 0 |

기준 RGB `(32,64,3)`에서 권장 프로파일의 스펙 입력 강도는 약 **0.0439**, 지수는 약 **11.04**다. 기존 `ksSpecular=0.8`, `ksSpecularEXP=10`을 유지하면 같은 맵에서 강도 약 **0.1004**, 지수 약 **3.51**가 된다. 기존 값은 밝은 반사가 더 넓게 퍼지는 쪽이다. 권장값은 그 강도를 낮추면서 섬유 결을 읽을 수 있게 지수를 조절한 시작점이다. 게임 밝기는 CSP 조명·시선각·감마 처리에도 영향을 받는다.

이 프로파일의 `useDetail=0`은 첨부 디퓨즈/노멀을 기준으로 한 설정이다. 기존의 `BODY_INT_FABRIC_2K_txDetail.png`를 의도적으로 중첩하고 있다면 재질 템플릿의 해당 슬롯과 `useDetail`을 유지해 비교한다. txMaps만 연결할 때는 detail 설정을 변경할 필요가 없다.

광택이 과하면 먼저 `ksSpecular`를 0.35→0.25로 내린다. 하이라이트를 더 넓게 하려면 `ksSpecularEXP`를 40→25로 내린다. 섬유가 플라스틱처럼 보일 정도로 B 또는 fresnel을 올리지 않는다.

## 재현 범위

섬유 재질의 외관은 작은 결 및 조명·시선각에 따른 반사 변화에 영향을 받는다. 부드러운 섬유 질감은 기존 디퓨즈와 노멀로 유지하고 txMaps는 낮은 강도와 넓은 하이라이트를 보조하도록 만들었다. [Irawan & Marschner, Specular Reflection from Woven Cloth](https://www.cs.cornell.edu/~srm/publications/TOG12-cloth.html)

알칸타라 제조사는 부드러운 촉감과 소재의 특성을 설명하지만, 이번 ks 재질 수치를 제시하지 않는다. 위 값은 이 모델을 위한 조정값이며 실측 알칸타라 BRDF 변환값은 아니다. [Alcantara 소재 설명](https://www.alcantara.com/the-material/)

네이티브 MultiMap은 단일 등방성 스펙 항이므로 섬유의 방향성 광택이나 velvet의 retroreflection을 온전히 재현하지 못한다. 해당 효과에는 별도 셰이더 항이 필요하다. 이번 작업은 txMaps와 적용용 재질 설정까지이며, 새 KN5의 게임 렌더 검증은 아직 수행하지 않았다.

## 포맷·검증

DDS는 비압축 **RGBA8 UNORM**, alpha 255, **12단계 전체 MIP**, 약 **21.3 MiB**다. 낮은 채널 값과 미세한 차이를 그대로 보존하기 위해 BC 압축하지 않았다. PNG는 같은 베이스 픽셀을 갖는다.

검증: 입력 해시 불변, 원본·출력 크기, BODY_FABRIC UV 대응, 채널 범위, 패딩 값, DDS 헤더·MIP 수·길이·불투명 알파, PNG와 DDS 베이스 픽셀 일치. 미리보기의 고정 조명 타일은 단순 Blinn-Phong 계산이며 게임 캡처가 아니다.

재생성 도구: `docs/tools/build_fabric_alcantara_maps.py`. 다른 시안은 `--version v2`로 저장할 수 있다. 새 모델에서 BODY_FABRIC UV까지 바뀌면 `--model <새 KN5>`를 지정하고 UV 마스크가 노멀과 맞는지 다시 확인한다.
