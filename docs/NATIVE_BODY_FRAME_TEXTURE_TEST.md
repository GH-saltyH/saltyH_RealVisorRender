# BODY_FRAME 외피: 네이티브 재질 후보 v1

## 사용할 결과

디퓨즈와 노멀을 고정하고 `txMaps`와 파라미터를 만들었다. 출력 폴더는 다음과 같다.

`ModelWorks/_2_blender_f1-helmet-lando_2025championWinner/texture/native_body_frame_test_v1/`

| 목적 | 셰이더 | txMaps | 프리셋 |
| --- | --- | --- | --- |
| 요청한 셰이더의 시작값 | `ksPerPixelMultiMap` | `BODY_FRAME_balanced_txMaps.dds` | `material_balanced.ini` |
| 더 선명한 반사 | `ksPerPixelMultiMap` | `BODY_FRAME_crisp_txMaps.dds` | `material_crisp.ini` |
| Gamma Fix 경로 | `ksPerPixelMultiMap` | 위와 같은 맵 | `material_balanced_gamma.ini` / `material_crisp_gamma.ini` |
| 금속 마스크 비교, 코팅 강도 0 | `nePBR_MultiMap_ClearCoat` | `BODY_FRAME_pbr_txMaps.dds` | `material_pbr.ini` |
| 금속과 도장 위에 코팅 반사를 함께 비교 | `nePBR_MultiMap_ClearCoat` | 위 PBR 맵 | `material_pbr_clearcoat.ini` |

PBR 대안은 CSP에서 제공하는 `nePBR_MultiMap_ClearCoat`이며 Kunos 기본 셰이더와는 구분된다. 프로젝트의 커스텀 HLSL을 추가하는 방식은 아니다. 로컬에 있는 소스는 컴파일·실행했지만, 현재 게임에 설치된 CSP에서 해당 셰이더를 실제로 로드하는지는 게임 테스트가 필요하다. 코팅 강도 0 / 0.25 두 프리셋을 제공한다.

## 패턴에서 확인한 내용

파일명을 기준으로 roughness나 metalness 역할을 정하지 않았다.

- `BODY_FRAME_4K_METALLIC.png`의 RGB는 동일한 스칼라이고, 거의 검정인 배경 위의 밝은 패치가 디퓨즈의 은색 스티커 위치와 일치했다. 밝은 구역은 전체 텍스처의 약 0.24%다. 이 위치를 은색 구역 마스크로 썼다.
- `BODY_FRAME_4K_NOTUSED.png`도 RGB가 동일하다. 넓은 흰 부분과, 통풍구 격자·작은 홈 위치의 검정 패턴으로 구성된다. 검정 부분을 홈의 반사 억제에 사용했다. 흰 영역 전체를 거친 표면으로 해석하거나 맵을 통째로 반전해 gloss에 연결하지 않았다.
- 디퓨즈에는 연두색·검정 도장과 은색 스티커가 이미 들어 있다. 노멀에도 도장 경계와 홈의 표면 변화가 들어 있다. 검정 도장에 흰 반사 색을 덧그리지 않고, 기존 노멀과 환경 반사로 하이라이트를 만든다.

원본 2K 디퓨즈와 1K 노멀은 **DDS 파일 전체를 바이트 그대로 복사**했다. 변환하거나 다시 압축하지 않았다. 시험 실행에도 각 DDS에 원래 들어 있던 12개/11개 mip을 디코딩하여 사용했다.

## ksPerPixelMultiMap 연결과 파라미터

| 슬롯 | 파일 / 의미 |
| --- | --- |
| `txDiffuse` | 원본 `BODY_FRAME_2K_txDiff.dds` |
| `txNormal` | 원본 `BODY_FRAME_1K_txNormal.dds` |
| `txMaps` | `BODY_FRAME_balanced_txMaps.dds` |
| `txDetail` | `neutral_white.dds`, `useDetail=0` |

txMaps 채널:

- **R:** 스페큘러 강도. 도장 약 0.48, 은색 구역 최대 0.91, 홈은 감소.
- **G:** 스페큘러 지수와 환경 반사 블러를 제어. balanced 도장 약 0.88, crisp 약 0.96. 은색 구역은 더 높은 값.
- **B:** 환경 반사 강도. 도장 약 0.72, 은색 구역 최대 1.0, 홈은 감소.
- **A:** CSP의 `extColoredReflection=2`가 사용하는 반사 색 마스크. 은색 구역만 디퓨즈 색에 맞춰 반사를 조절한다. 투명도나 물리적인 metalness 채널이 아니다.

레거시 시작값:

```ini
ksAmbient=0.4
ksDiffuse=0.6
ksSpecular=0.65
ksSpecularEXP=255
ksEmissive=0,0,0
fresnelC=0.08
fresnelEXP=5
fresnelMaxLevel=0.85
isAdditive=0
useDetail=0
nmObjectSpace=0
extColoredReflection=2
extColoredReflectionNorm=0
```

Gamma Fix 프리셋은 `ksAmbient=0.25`, `fresnelC=0.282842712`, `fresnelEXP=2.272727273`, `fresnelMaxLevel=0.921954446`을 사용한다. Fresnel 값은 로컬 소스의 제곱/지수 변환을 보정한 것이다. 게임의 노출·환경맵·후처리에 맞춘 색상 보정까지 완료한 값은 아니다.

외피는 **Opaque**, Alpha Blend/Alpha Test 끄기, 기본 Depth 모드 (`DEPTHMODE=0`)다. `[MATERIAL_0]`과 `NAME`은 실제 외피 재질 번호/이름으로 교체한다. 원래 활성 재질이 커스텀 셰이더라면 실제로 그려지는 패스에 이 설정을 연결해야 한다.

`extColoredReflection`은 CSP 확장이다. 이 기능을 사용할 수 없는 기본 경로에서는 `extColoredReflection=0`으로 흰 스페큘러를 사용해도 RGB 채널의 도장 광택은 유지된다.

## 요청한 셰이더로 가능한 부분과 한계

유광 도장, 검정 도장 위의 흰 하이라이트, 은색 부분의 더 강하고 선명한 반사는 `ksPerPixelMultiMap`으로 근사할 수 있다. 그러나 이 셰이더는 한 재질에 공통 Fresnel 시작값/최댓값을 적용한다. B는 반사 배율이고 물리적인 metalness가 아니다. 은색 구역의 확산광을 제거하면서 정면 반사율을 금속 수준으로 독립 설정하는 기능도 기본 RGB 맵에는 없다.

따라서 **참고 이미지의 도장과 은색 금속을 서로 다른 물리적 반사로 재현하는 데는 PBR 후보가 더 적합**하다. 전체 `fresnelC`를 높여 은색을 강화하면 도장 쪽에도 영향을 주므로 그렇게 처리하지 않았다.

참고 이미지의 작은 구불거리는 반사 디테일은 고정된 1K 노멀에 남아 있는 정보까지 표현 가능하다. txMaps를 크게 만들어도 노멀에 없는 구김을 복원하지 않는다. 새 txMaps는 디퓨즈와 같은 2048×1024, RGBA8 UNORM, 1×1까지 12개 mip으로 만들었다.

## PBR 대안 연결

**PBR txMaps는 ksPerPixelMultiMap 맵과 채널 의미가 다르므로 서로 바꾸어 연결하면 안 된다.**

| 채널 | PBR 맵 의미 |
| --- | --- |
| R | smoothness: 도장 약 0.88, 은색 최대 0.94, 홈에서 감소 |
| G | 은색 구역의 metalness 마스크 |
| B | reflectance 선택값. 현재 프리셋은 양쪽 범위를 0.04로 고정하므로 B에 따른 변화 없음 |
| A | 홈의 occlusion. 도장 1.0, 홈 최소 0.65 |

핵심 PBR 값:

```ini
pbSmoothness=0,1
pbMetalness=0,1
pbReflectance=0.04,0.04
pbOcclusion=0,1
pbOcclusionSource=2
pbOcclusionMult=1
pbColorSource=0
pbReflectionBlurEnv=0
extStickersMode_uint=0
ksDiffuse=1
ksAmbient=1
ksEmissive=0,0,0
useDetail=0
```

ClearCoat 프리셋의 추가값:

```ini
pbClearCoatSmoothness=0.82,0.96
pbClearCoatIntensity=0.25
pbClearCoatF0=0.04
pbClearCoatNormalShare=0
```

디퓨즈·노멀은 같은 원본 파일을 유지하며, `txDetail`은 흰 중립 맵, `txEmissive`는 검정 중립 맵으로 연결한다. 이 셰이더는 기본 normal을 공유한 코팅층을 계산하므로 새 노멀 텍스처가 필요 없다. 별도로 붙은 투명 액세서리의 입체감은 그 액세서리 메쉬/재질에서 처리해야 한다.

## 검증 기록

로컬 기본·Gamma Fix·PBR ClearCoat 셰이더를 컴파일하고 D3D11 WARP에서 실행했다. 모든 출력은 유한한 값, 외피 알파는 1.0이었다. 광원·주변광·환경맵을 모두 끈 조건에서는 기본/PBR 모두 RGB가 0이므로 자체 발광을 사용하지 않는다.

동일한 은색 texel에서 PBR metalness만 제거하는 비교로 은색 마스크가 환경 반사에 실제로 작동함을 확인했다. 고정 노멀과 평탄한 노멀을 비교하여 노멀의 반사 변화도 확인했다. 샘플값은 실제 게임 밝기가 아니다.

로컬의 일반 `nePBR_MultiMap` 소스에서는 WITHOUT_NMDETAIL/Hill12 분기가 노멀을 읽고도 표면 방향에 적용하지 않는 문제가 보여, `getNormalW`를 호출하는 ClearCoat 버전을 선택했다. 코팅 강도를 0으로 두어도 이 버전은 고정 노멀을 적용한다. 게임 설치본의 다른 버전까지 동일한 문제라고 단정하지 않는다.

PBR 시험에는 수치 적분한 GGX BRDF LUT와 인공 스튜디오 큐브맵을 사용했다. 게임이 제공하는 CSP LUT와 환경맵을 그대로 재현한 시험은 아니다. 미리보기는 실제 헬멧의 3D 렌더가 아니라 인공 원통 방향으로 UV 아틀라스를 조명한 결과다. 헬멧 메쉬, 접선, 실제 조명, 노출, PP 필터와 CSP 설치 버전은 게임에서 확인해야 한다.

원본/출력 SHA256과 프리셋·샘플값은 `asset_manifest.json` 및 `docs/diagnostics/2026-10-11/native-body-frame/validation.json`에 기록했다. 재생성 도구는 `docs/tools/build_body_frame_native_maps.py`다.
