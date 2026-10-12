# 투명 윙 재질 v1

## 기본 선택과 파일

기본 셰이더는 **`ksPerPixelNM_UVMult`**이다. 프로젝트의 기존 diet FBX 설정에서도 사용한 셰이더이며, 디퓨즈 알파·탄젠트 노멀·환경 반사와 각도에 따른 알파 증가를 처리한다. 투명 플라스틱의 균일한 반사에는 두 텍스처로 충분하다. `ksPerPixelReflection`에는 이 소스 기준 탄젠트 노멀 텍스처 처리가 없고, 일반 `ksPerPixelMultiMap`은 출력 알파가 1이어서 기본안으로 선택하지 않았다.

출력: `ModelWorks/_2_blender_f1-helmet-lando_2025championWinner/texture/native_wing_plastic_test_v1/`

| 용도 | 프리셋 | 디퓨즈 입력 알파 |
| --- | --- | --- |
| 투명도를 가장 높게 | `material_nm_clear.ini` | 3/255, 약 1.2% |
| 시작값 | **`material_nm_balanced.ini`** | 8/255, 약 3.1% |
| 더 잘 보이는 표면 | `material_nm_defined.ini` | 16/255, 약 6.3% |
| Gamma Fix용 | 각 프리셋의 `_gamma.ini` | 같은 텍스처 |
| 기존 노멀 UV를 유지한 메쉬에만 | `material_nm_balanced_legacyUV.ini` | balanced |
| 이후 부위별 반사 마스크가 필요한 경우 | `material_multimap_balanced.ini` / `_gamma.ini` | balanced |

기본 슬롯은 `txDiffuse=WING_balanced_diffuse.dds`, `txNormal=WING_flat_normal.dds`다. clear/defined는 디퓨즈만 교체한다. 상수 텍스처는 **4×4**라 UV에 의존하지 않고 거의 메모리를 쓰지 않는다. 해상도를 올려도 균일한 색·알파의 품질은 개선되지 않는다. PNG와 DDS를 함께 제공하며, DDS는 RGBA8 UNORM과 끝까지 생성한 mip 체인을 사용한다.

## 실제 UV와 소스 패턴에서 확인한 사항

Blender 원본을 자동 스크립트 실행이 꺼진 백그라운드 모드로 읽었다. 저장하지 않았다. `WING_04`, `WING_TOPMOST`, `WING_TOPSIDE`는 모두 `mtBODY_WING_MIRROR`를 사용한다. 해당 재질의 노멀 노드에는 `BODY_WING_REAR_4K_txNormal.png`가 연결되어 있다.

다만 노드 연결 자체가 올바른 매핑을 보장하지 않는다. 현재 `WING_04`의 UV 범위는 대략 U 0–1 / V 0–0.325, 상단 두 윙은 U 0.011–0.141 / V 0.012–0.068 안쪽이다. UV와 프로젝트 노멀을 겹친 `uv_binding_inspection.png`를 제공한다. 기존 노멀의 성형선을 새 메쉬의 실제 경계라고 확정할 수 없어, **새 메쉬용 기본안은 플랫 노멀과 메쉬 자체의 곡률·베벨·스무딩 노멀을 사용한다.**

`MRR_BODY_WING_2K_txNormal.png`는 넓은 평탄 구역과 일부 접힘/테두리의 강한 노멀로 구성되어 있다. 이를 방향 정규화한 `WING_legacyUV_normal.dds`도 만들었지만, 원래 UV를 유지한 메쉬용 옵션이다. 새 UV의 정점 좌표를 옮기거나 이 노멀을 무조건 덮어씌우지 않았다.

공용 `GLASS__BODY_HighRes_txNormal.png`에는 바이저 띠·각인·작은 여러 부품이 한꺼번에 들어 있다. `GLASS_BODY_HighRes_ALPHA.png`의 RGB에도 큰 면별 구분, 띠와 여러 부품 패턴이 있으며 실제 알파 채널은 255다. 따라서 이름만 보고 투명 윙 전체의 불투명도나 거칠기에 연결하지 않았다.

기존 `MRR_WING_DIFF.dds`는 4×4, 모든 픽셀 RGBA=(77,77,77,64)로 약 25% 입력 알파다. 새 디퓨즈는 RGB 77을 유지하면서 알파를 낮췄다. 원본 스크린샷의 흰 하이라이트는 텍스처에 그리지 않고 환경·광원 반사로 나타나게 한다. 나사/고정 부품은 실제 별도 메쉬/재질을 유지해야 한다. 이미지의 어두운 나사를 윙 알파에 새로 그리지 않았다.

## 주요 시작 파라미터

| 파라미터 | 기본값 | 의도 |
| --- | --- | --- |
| `ksAmbient` / `ksDiffuse` | 0.15 / 0.10 | 투명 플라스틱 자체의 회색 확산색 억제 |
| `ksSpecular` | 0.85 | 성형선·베벨의 밝은 광원 반사 |
| `ksSpecularEXP` | 235 | 날카로운 반사, 약간의 블러 |
| `fresnelC` | 0.04 | 정면 반사 시작값; 실제 IOR 측정값은 아님 |
| `fresnelEXP` | 5.208333 | 현 로컬 NM 셰이더의 추가 지수 스케일을 고려 |
| `fresnelMaxLevel` | 0.8 | 비스듬한 방향에서 표면 반사가 살아남 |
| `diffuseMult` / `normalMult` | 0 / 0 | UV 반복 추가 없음 |
| `ksEmissive` | 0,0,0 | 자발광 없음 |
| `extColoredReflection` | 0 | 반사색을 회색 디퓨즈로 착색하지 않음 |

`ALPHABLEND=1`, `ALPHATEST=0`, `DEPTHMODE=1`(깊이 읽기, 쓰기 제외)을 사용한다. 프리셋의 `[MATERIAL_0]`은 템플릿 인덱스다. 실제 FBX INI의 윙 재질 인덱스에 값을 옮기고 리소스를 등록한다. 확인한 Full INI에서는 `[MATERIAL_17]`이지만 다른 파일에 이 번호를 그대로 적용하면 안 된다. 원본 FBX/Blend/INI와 런타임은 수정하지 않았다.

Gamma Fix 프리셋은 로컬 소스의 Fresnel 변환을 고려해 C=0.2, Max≈0.894427, EXP≈2.367424로 대응시켰다. 실제 설치된 CSP·PP·조명과 동일한 전체 색감을 보장하는 변환은 아니다. 해당 렌더 경로에 맞는 한 프리셋만 선택한다.

## MultiMap 대안

`ksPerPixelMultiMap_emissive`의 맵 옵션도 제공한다. 기본 투명 윙에 반드시 필요한 옵션은 아니며, 이후 접착부/무광 구역에 다른 반사를 넣을 때 선택한다.

- `txDiffuse`: balanced 디퓨즈.
- `txNormal`: 기본 플랫 노멀.
- `txMaps`: `WING_uniform_maps.dds`, RGBA=(235,242,255,255). R은 스페큘러 강도, G는 지수·반사 블러, B는 환경 반사 강도. A는 이 설정에서 쓰지 않으며 투명도가 아니다.
- `txDetail`: `neutral_white.dds`, `useDetail=0`.
- `txEmissive`: `neutral_black.dds`, `ksEmissive=0`.
- `emAlphaFromDiffuse=-1`, `isAdditive=0`, `nmObjectSpace=0`, `extColoredReflection=0`.

이 옵션은 CSP의 emissive 확장 셰이더 이름을 사용하지만 여기서는 자발광을 만들지 않는다. 순수 Kunos 기본 재질로 시작할 때는 NM 기본안을 사용한다.

## 검증 범위와 실제 형상의 조건

로컬의 실제 두 픽셀 셰이더를 컴파일하고 **D3D11 WARP**에서 합성 UV 원통·스튜디오 큐브 환경으로 실행했다. 출력 알파의 각도 변화, 발광이 없는 어두운 환경, 노멀 교체에 따른 출력 변화, Gamma Fix 경로의 정면 알파 대응을 확인했다. balanced의 단일 표면 출력 알파는 정면 0.06999, 45° 0.07216, 75° 0.28652, 85° 0.65918이었다. 광원/환경광을 없앤 시험에서 RGB는 모두 0이었다. 수치는 `asset_manifest.json`과 진단 폴더의 `validation.json`에 기록된다. 비교 이미지는 이 시험의 출력이며 게임에서 찍은 헬멧 렌더가 아니다.

두 셰이더는 알파 합성과 반사를 제공하며 **뒤쪽 헬멧 이미지의 실제 굴절·두께에 따른 왜곡을 계산하지 않는다.** 참고 이미지와 같은 윤곽은 메쉬의 곡률/두께/베벨/법선에 크게 의존한다. 플랫 노멀만 썼는데 윤곽이 약하면 디퓨즈에 흰 선을 추가하기 전에 실제 메쉬 베벨과 스무딩부터 확인한다.

닫힌 입체의 앞·뒷면이 모두 그려지면 투명도는 두 번 누적된다. 두 겹의 유효 알파는 `1-(1-a)^2`다. 정면 단일 표면 알파가 약 7%면 두 겹은 약 14%다. 이런 메쉬에는 clear 프리셋부터 비교한다. 깊이 쓰기나 겹친 복제 면 때문에 뒤쪽 도장/다른 윙이 사라지거나 그리기 순서가 뒤집히는 현상은 텍스처로 해결되지 않는다. 실제 게임에서 카메라를 돌려 Alpha Blend 정렬과 뒷면 노멀을 확인해야 한다. 성형선용 노멀과 미세 텍스처는 UV seam과 베벨이 올바르게 연결된 뒤 적용한다.

현재 프리셋은 실제 게임 실행·투명 정렬·DLSS 검증까지 한 결과는 아니다. 원본 보존은 SHA256으로 확인하고, ZIP은 CRC 검사를 수행한다.
