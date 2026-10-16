# 매끈한 EXT·COAT 및 STICKER 재질 v2

## 적용할 파일

패키지: `texture/리뉴얼/GLASS_smooth_and_sticker_v2.zip`

| 대상 | 시작 프리셋 | 텍스처 |
| --- | --- | --- |
| EXT | `material_EXT_smooth.ini` | `EXT_smooth_diffuse.dds`, `EXT_normal.dds`, `EXT_smooth_maps.dds` |
| COAT | `material_COAT_smooth.ini` | `COAT_smooth_diffuse.dds`, `COAT_smooth_normal.dds`, `COAT_smooth_maps.dds` |
| STICKER | `material_STICKER_balanced.ini` | `STICKER_balanced_diffuse.dds`, `flat_normal.dds`, `STICKER_balanced_maps.dds` |

모든 프리셋은 `ksPerPixelMultiMap_emissive`, Alpha Blend 켜기, Alpha Test 끄기, Depth Read Only다. Gamma Fix가 적용되는 렌더 경로에는 각 `_gamma.ini`를 사용한다. 모든 재질에 `txDetail=neutral_white.dds`, `useDetail=0`, `txEmissive=neutral_black.dds`, `ksEmissive=0`을 지정한다. `[MATERIAL_0]`은 템플릿 인덱스이므로 실제 대상 재질 블록으로 옮긴다. 확인한 Full FBX INI의 대상은 `mtGLASS_COATING` 10번, `mtGLASS_EXT` 11번, `mtGLASS_STICKER` 13번이지만 이후 내보내기에서 번호가 달라질 수 있다.

텍스처는 PNG와 RGBA8 UNORM DDS를 함께 제공한다. 큰 맵은 4096×1024 / 13 mip, 플랫 노멀·중립 텍스처·균일한 STICKER txMaps는 4×4 / 3 mip이다. 원본·이전 v1·현재 FBX 설정·게임 런타임은 이 작업에서 덮어쓰지 않았다.

## 자글자글하게 보인 원인과 수정

이전 생성 코드에는 다음 문제가 있었다.

- EXT의 `scuff`를 유리 RGB, 알파, specular, gloss, reflection 모두에 사용했다. balanced 입력 알파가 대략 0.09–0.21로 미세 패턴에 따라 변했고 RGB도 약 22/255 폭으로 달라졌다. 반사가 약한 각도에서도 패턴이 남을 수 있는 구조였다.
- COAT의 미세 `grain`을 RGB·알파·gloss에 넣었다. 큰 주름과 끝부분 흐림에 작은 불투명도 얼룩·반사 블러까지 더해져 매끈한 필름보다 거친 표면에 가까워질 수 있었다.
- 검토 시점의 실제 Full INI는 COAT `emAlphaFromDiffuse=1`, EXT `ksSpecularEXP=350`, `fresnelEXP=1`이었다. 지수만 크게 올려도 diffuse/alpha의 패턴은 제거되지 않는다. 값 350은 로컬 반사 블러 계산의 기준 255보다 크지만 색·알파 문제를 해결하지 않는다.

v2에서는 **미세 패턴을 디퓨즈 색과 알파에서 제거**했다. EXT의 투명 구역은 일정 RGB와 입력 알파 약 0.055다. 인쇄 띠/실제 스티커 위치의 색과 불투명도는 유지한다. COAT는 큰 주름 노멀, 완만한 끝부분 흐림, 각인 문자만 색·알파에 남긴다. COAT 노멀은 벡터를 저역 필터링하고 XY 세기를 0.85로 줄여 큰 주름을 보존한다. 새 미세 높이/노멀을 만들지 않았다.

미세 패턴은 txMaps **R(스페큘러 강도)**과 **B(환경 반사 강도)**에만 약하게 남겼다. EXT는 R 변동 최대 0.075, B 변동 최대 0.020; COAT는 각각 0.070, 0.018이다. G에는 미세 패턴을 넣지 않아 좁은 하이라이트의 블러가 자글자글하게 변하지 않는다. COAT 끝부분의 G만 낮은 주파수로 조금 변한다. 따라서 이 디테일은 광원/환경 반사로 드러나며 기본색 얼룩으로 고정되지 않는다.

네이티브 셰이더의 마스크 방식이라 특정 각도에서만 갑자기 켜지는 별도 게이트는 아니다. 광원의 스페큘러 로브와 환경 반사에 따라 패턴의 대비가 달라진다. 정확한 다층 미세 산란/박막 모델을 복원한 것은 아니다.

### 주요 파라미터

| 값 | EXT | COAT | STICKER |
| --- | --- | --- | --- |
| `ksAmbient` / `ksDiffuse` | 0.20 / 0.25 | 0.20 / 0.25 | 0.25 / 0.35 |
| `ksSpecular` / `ksSpecularEXP` | 0.65 / 255 | 0.45 / 255 | 0.55 / 255 |
| `fresnelC` / `fresnelEXP` / `fresnelMaxLevel` | 0.04 / 5 / 0.55 | 0.025 / 5 / 0.35 | 0.035 / 5 / 0.55 |
| `emAlphaFromDiffuse` | -1 | -1 | **1** |

EXT·COAT의 -1은 디퓨즈 알파를 쓰면서 각도별 Fresnel 알파 증가를 허용한다. STICKER의 1은 마스크로 제거한 부분이 비스듬한 각도에서도 다시 나타나지 않도록 출력 알파를 고정한다. Gamma Fix에서는 C와 Max를 제곱근, EXP를 2.2로 나눈 프리셋을 제공한다. 실제 엔진 경로와 PP에 맞는 한 프리셋만 사용한다.

## STICKER의 검정 부분 해석

사용한 유일한 소스는 지정한 `GLASS_STICKER_txDetail.png`다. 파일명으로 detail·높이·거칠기 역할을 정하지 않았다. 패턴은 가운데 흰 띠, 양쪽 검정 구역, 가장자리의 점진적인 밝기 변화와 유효 영역 알파로 구성된다. 현재 Blender의 `GLASS_STICKER_MRR` UV와 겹쳐 확인한 이미지도 제공한다.

보이는 구역은 `원본 coverage × (1 - unpremultiply(RGB)/253)`로 계산한다. **전체 배경의 검정까지 반전하지 않는다.** 원본 알파가 0인 바깥/구멍은 출력 알파도 0이다. 중앙 흰 부분은 투명, 검정 끝부분은 옅은 회색의 반투명 필름이다. 마스크 검정을 재질의 검정 색으로 사용하지 않았다.

- clear: 검정 끝부분 입력 알파 0.18.
- balanced: 약 0.30, 기본안.
- defined: 약 0.42, 더 뿌연 필름.
- 흰 구역과 원본 영역 밖: 알파 0.
- 기본 노멀은 플랫. 광택은 G≈0.97, 환경 반사 강도는 B≈0.92.

단 하나의 밝기 마스크로는 레퍼런스의 구겨진 접힘 형태나 실제 두께를 결정할 수 없다. 주름 형태는 메쉬 곡률/스무딩 노멀로 표현되며, 추가 주름을 정확하게 원하면 STICKER 자체 UV의 노멀 베이크가 필요하다. 마스크를 높이로 바꾸거나 COAT 노멀을 다른 UV에 재사용하지 않았다. 메쉬는 구멍과 외곽을 제공하고 텍스처는 필름의 보이는 구역을 제공한다.

현재 Blender 원본의 `GLASS_STICKER_MRR`는 렌더 표시가 켜져 있지만 `GLASS_STICKER`/`GLASS_STICKER_MIRROR`는 꺼져 있다. 실제 내보낸 메쉬의 표시/재질 연결도 함께 확인한다.

## 검증 및 남는 형상 문제

로컬 `ksPerPixelMultiMap_emissive` 픽셀 셰이더를 컴파일하고 D3D11 WARP의 합성 UV 원통/스튜디오 환경에서 실행했다. 다음을 검사한다.

- 스페큘러와 환경 반사를 제거하면, v2 패턴 맵과 균일 맵의 RGB·알파 출력 차이가 사라짐.
- 반사를 켜면 패턴 맵이 출력에 영향을 줌.
- STICKER 검정 위치의 반투명 알파, 흰 위치/바깥의 알파 0을 정면 및 75°에서 유지.
- 조명 없는 STICKER는 RGB 0, 자발광 없음.
- Legacy 및 Gamma Fix 셰이더가 컴파일·실행되고 출력이 유한함.
- 원본 소스 SHA256 보존, DDS의 mip/픽셀 확인, ZIP CRC 확인.

자세한 수치는 `asset_manifest.json` 및 진단 폴더 `validation.json`에 들어 있다. 비교 PNG는 실제 네이티브 셰이더 코드의 합성 시험 출력이다. 실제 게임/헬멧 메쉬/투명 정렬을 검증한 스크린샷은 아니다.

검증 결과 EXT 유리 구역 RGB는 모든 픽셀이 (22,23,24), 알파는 14/255, G는 249/255였다. 같은 구역의 v1 알파는 23–58/255였다. 반사와 스페큘러를 끈 패턴 맵/균일 맵 비교에서 EXT와 COAT 모두 최대 출력 차이는 **0.0**이었다. STICKER balanced의 검정 위치 알파는 정면/75° 모두 0.298039, 흰 위치와 바깥은 모두 0.0이었다. 조명 없는 STICKER의 RGB도 0.0이었다.

제공 이미지의 수평 면 경계나 반사 각도의 계단식 차이가 수정 후에도 남으면 미세 패턴 문제와 별도로 확인해야 한다. Blender의 대상들은 smooth face와 custom normals를 사용하므로 단순히 Shade Smooth만 켜는 것으로 충분하다고 단정할 수 없다. `material_EXT_smooth_flat_diagnostic.ini`, `material_COAT_smooth_flat_diagnostic.ini`로 텍스처 노멀을 제거한 비교가 가능하다. 이 상태에서도 경계가 남으면 메쉬의 분리된/잠긴 노멀, 중복 표면, 삼각형 접합과 투명 정렬을 확인한다. 이 작업은 그 노멀을 일괄 삭제하거나 메쉬를 수정하지 않았다.
