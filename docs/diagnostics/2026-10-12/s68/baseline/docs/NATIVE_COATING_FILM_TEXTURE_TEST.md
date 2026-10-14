# COATING 필름 텍스처 조합 v1

## 결과와 확인 범위

제공한 여섯 PNG의 실제 픽셀과 패턴을 기준으로 만든 `ksPerPixelMultiMap_emissive`용 후보다. 원본 파일, 메쉬, 게임 설정은 수정하지 않았다.

출력 폴더: `ModelWorks/_2_blender_f1-helmet-lando_2025championWinner/texture/리뉴얼/native_coating_film_test_v1/`

`balanced`부터 비교한다. `clear`는 투명한 중앙과 약한 끝부분, `cloudy`는 끝부분의 회색 필름감이 강하다. 모든 후보는 같은 UV와 같은 구김 노멀을 사용한다.

로컬 CSP 셰이더 소스를 컴파일하여 D3D11 WARP에서 인공적인 원통 방향, UV, 스튜디오 환경맵으로 실행했다. 미리보기는 그 출력 RGBA를 체크 배경에 합성한 것이다. 실제 KN5, 게임 내 조명, 투명 레이어 정렬, DLSS는 검증 대상에 포함되지 않는다.

## 패턴별 역할

파일명의 의미를 가정하지 않고 내부 패턴을 비교했다. 여섯 파일은 동일한 알파 외곽/구멍 마스크를 갖고, 완전히 덮인 내부 픽셀의 알파는 모두 255다. 그대로 투명도에 연결하면 필름이 불투명해진다.

| 확인한 패턴 | 사용한 역할 |
| --- | --- |
| NOISE3: 양끝이 밝고 중앙이 거의 검정, 부드러운 전이 | 끝부분의 높은 알파와 낮은 광택을 만드는 주 마스크 |
| NOISE1: 넓은 얼룩과 미세 입자 | 약한 알파 변화, 미세한 광택 변화 |
| NOISE2: 중앙의 검은 큰 반점과 밝은 주변 | 작은 광택 변화. 검은 반점을 구멍으로 처리하지 않음 |
| SIGN: 흰 필름 위 회색 문자 | 문자 위치를 추출해 RGB를 어둡게 하고 해당 부분의 알파를 높임 |
| CUTPATTERN: 양끝과 구멍 주변의 소수 밝은 조각 | 국소적인 알파/광택 변화. 실제 절단 위치인지는 확인되지 않아 메쉬나 알파에 구멍을 추가하지 않음 |
| txNormal: 중앙이 비교적 평탄하고 양끝이 크게 구겨짐 | 원래 구김 방향을 유지하고 벡터를 정규화한 탄젠트 노멀 |

문자는 UV 원위치를 유지했다. 흰 배경을 RGB에 그대로 넣으면 전체 필름이 흰색 막처럼 되므로 문자 마스크만 추출한다. 참고 이미지에서 보이는 문자의 실제 각인 깊이는 알 수 없다.

## 연결 방법

| 슬롯 | 연결 파일 |
| --- | --- |
| `txDiffuse` | `COAT_balanced_diffuse.dds` — RGB: 회색 필름과 문자, A: 재구성한 불투명도 |
| `txNormal` | `COAT_normal.dds` — 기본 구김. 원본 알파 외곽도 유지 |
| `txMaps` | `COAT_balanced_maps.dds` — R: 스페큘러 강도, G: 광택 지수 제어, B: 환경 반사 배율 |
| `txDetail` | `neutral_white.dds`; `useDetail=0` |
| `txEmissive` | `neutral_black.dds`; `ksEmissive=0` |

후보를 바꿀 때 diffuse와 maps를 같은 후보명으로 함께 교체한다. txMaps는 ORM 텍스처가 아니다. G는 네이티브 셰이더의 지수와 반사 블러에 영향을 주는 값이며, 물리적인 PBR roughness 변환을 가정하지 않았다.

`material_balanced.ini`는 레거시 경로, `material_balanced_gamma.ini`는 Gamma Fix 경로의 시작값이다. `[MATERIAL_0]`과 `NAME`은 실제 COATING 재질에 맞게 변경해야 하는 자리표시자다.

핵심 설정:

- Alpha Blend 켜기, Alpha Test 끄기, Depth Read Only (`DEPTHMODE=1`). 투명 레이어의 실제 정렬은 게임에서 확인한다.
- `emAlphaFromDiffuse=-1`: diffuse의 재구성한 알파를 사용하고 각도에 따른 Fresnel 알파도 반영한다.
- `isAdditive=0`, `nmObjectSpace=0`, `useDetail=0`.
- 레거시: `ksSpecular=0.45`, `ksSpecularEXP=255`, `fresnelC=0.025`, `fresnelEXP=5`, `fresnelMaxLevel=0.30`.
- Gamma Fix: `fresnelC=0.158113883`, `fresnelEXP=2.272727273`, `fresnelMaxLevel=0.547722558`. 소스 내부의 변환을 보정해 레거시와 같은 알파를 만든다.

EXT 위에 놓이는 별도 필름이므로 이전 EXT 후보보다 반사 시작값을 낮췄다. 두 재질의 반사가 더해지는 정도는 실제 레이어 구성과 조명에 맞춰 조절해야 한다. `emAlphaFromDiffuse=1`로 바꾸면 Fresnel에 따른 알파 증가 없이 텍스처 알파만 비교할 수 있다.

## 각인 노멀 선택

기본 프리셋은 `COAT_normal.dds`를 쓴다. `COAT_normal_shallow_engraving.dds`는 문자 마스크로 만든 매우 얕은 오목 노멀을 기존 구김에 더한 선택 후보다. 측정된 각인 형상은 아니므로 실제 렌더에서 더 자연스러운 경우에만 사용한다. 문자 색/알파는 두 노멀 모두 동일하다.

노멀은 RGB 색을 단순히 섞지 않고 탄젠트 기울기로 합성하고 다시 정규화했다. 원본 UV의 구김을 보존하고, 아일랜드 경계 바깥 16픽셀에는 주변 데이터를 연장했다. 4096×1024 PNG와 RGBA8 UNORM DDS를 함께 제공하며, DDS는 1×1까지 13개 mip을 갖는다. 작은 중립 맵은 3개 mip이다. 노멀 mip은 벡터를 재정규화하고, 색 mip은 알파 가중 필터링을 한다.

## 표현의 한계와 실제 비교 순서

이 셰이더의 알파 블렌딩은 회색 필름이 겹치는 인상을 낼 수 있지만, 뒤의 장면을 실제로 굴절시키거나 뿌옇게 블러하는 투과 산란은 구현하지 않는다. 참고 이미지의 넓고 휘어진 하이라이트는 노멀과 환경 조명이 함께 만들어야 한다. 흰 반사 무늬를 diffuse나 emissive에 고정해서 넣지 않았다.

현재 앱의 COATING이 커스텀 셰이더로 그려지는 상태라면 네이티브 재질 프리셋만 변경해도 화면에 반영되지 않을 수 있다. 실제로 그려지는 패스에 이 슬롯을 연결해 비교해야 한다.

1. 같은 환경에서 COATING만 보며 `balanced`의 문자, 투명한 중앙, 뿌연 양끝을 확인한다.
2. 고정된 밝은 광원 아래에서 바이저 각도를 바꿔 양끝 구김의 반사가 움직이는지 확인한다.
3. EXT를 함께 켜서 과한 밝기/불투명도와 레이어 정렬을 확인한다. 필요하면 `clear`로 비교한다.
4. 얕은 각인 노멀을 선택적으로 비교한다.

실행 기록과 원본 SHA256, 출력 DDS SHA256, 알파 측정값: 출력 폴더의 `asset_manifest.json` 및 `docs/diagnostics/2026-10-11/native-coating-film/validation.json`.

재생성 도구: `docs/tools/build_coating_film_textures.py`. 앞선 네이티브 EXT 테스트의 공통 DDS/셰이더 헬퍼와 WARP 실행기를 사용한다.
