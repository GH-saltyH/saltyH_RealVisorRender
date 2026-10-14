# EXT 바이저: 네이티브 MultiMap 텍스처 테스트

테스트 날짜: 2026-10-11. 대상은 **`ksPerPixelMultiMap_emissive`**이다.
로컬 CSP 소스의 메인 픽셀 셰이더를 FXC로 컴파일하고 D3D11 WARP에서 실행했다.
곡면 방향을 흉내 낸 UV 표면, 인공 스튜디오 큐브맵, 체크 배경을 사용한 비교이다.
게임 실행 화면, 실제 KN5의 UV·탄젠트·투명 정렬, DLSS, FPS를 검증한 결과는 아니다.

## 픽셀에서 확인한 역할

파일 이름의 일반적인 의미를 재질 입력으로 가정하지 않았다. 실제 패턴과 알파를 읽었다.

| 원본 | 확인한 패턴 | 이번 구현에서 사용한 역할 |
|---|---|---|
| GLASS_EXT_txDiff.png | 컬러 스폰서 띠, 작은 인증 스티커, 회색 얼룩 | 띠·스티커 RGB 보존. 글래스 RGB는 얇은 어두운 유리층에 맞춰 재구성 |
| GLASS_EXT_GLOSS.png | 실루엣 안에서 띠는 0, 글래스는 거의 253 | 반전하여 스폰서 띠 영역 분리 |
| GLASS_EXT_ROUGH.png | 띠와 그 주변에만 밝기 변화, 글래스 중앙은 0 | 띠의 하이라이트 폭과 주변 광택 변화 |
| GLASS_EXT_txDetail.png | 글래스의 회색 얼룩, 띠와 인증 스티커는 253 | 불투명 스티커 영역 분리. 글래스 얼룩을 광택·약한 불투명도 변화로 변환 |
| GLASS_EXT_txNormal.png | 띠 경계, 측면 굴곡, 각인 | 방향 유지, 벡터 정규화, UV 가장자리 패딩, 밉맵에서 재정규화 |

**다섯 파일 모두 글래스 내부의 알파는 255**였다. 알파는 투과율이 아니라 UV 실루엣에 해당한다.
네 개의 알파 배열은 완전히 동일했고, 노멀은 경계 34픽셀만 달랐다.
따라서 원본 디퓨즈를 그대로 넣어서는 투명 글래스를 얻지 못한다.
글래스 안에서 두 회색 얼룩 필드의 상관계수는 약 -0.601이다. 이들도 같은 마스크로 취급하지 않았다.

## 셰이더에서 확인한 입력

| 입력 | 실제 역할 | 연결할 테스트 파일 |
|---|---|---|
| txDiffuse RGB | 표면 색 | EXT_balanced_diffuse.dds |
| txDiffuse A | 이번 설정의 불투명도 입력 | 위 파일에 포함. 띠/스티커 1, 글래스 0.09–0.21 |
| txNormal RGB | 탄젠트 공간 노멀 | EXT_normal.dds |
| txMaps R | ksSpecular의 강도 배율 | EXT_balanced_maps.dds |
| txMaps G | ksSpecularEXP의 배율. 낮으면 넓은 하이라이트와 흐린 환경 반사 | 위 파일에 포함 |
| txMaps B | 환경 반사 강도 배율 | 위 파일에 포함 |
| txDetail | useDetail 활성화 시 디퓨즈에 곱해지는 디테일 | neutral_white.dds, useDetail=0 |
| txEmissive | 발광 마스크/색 | neutral_black.dds, ksEmissive=(0,0,0) |

`txMaps`는 PBR ORM이나 metallic/roughness 패킹이 아니다.
G의 생성식 `(1-r)^2`는 이번 비교용 광택 배분식이며 물리 roughness의 정확한 변환식이 아니다.
본 셰이더에서 환경 반사 밉 선택은 G와 ksSpecularEXP에 따른 비선형 식으로 결정된다.
밝은 스튜디오 반사, 표면 광택 차이, 투명도 차이는 표현할 수 있다.
IOR/두께에 따른 굴절, 얇은 코팅의 간섭색, 광선의 내부 다중 반사는 이 텍스처 조합만으로 만들 수 없다.
참고 이미지의 긴 흰 반사는 장면 조명/환경 반사에서 공급해야 한다. 발광 띠로 대체하면 밤에도 빛난다.

## 후보와 재질 설정

출력 폴더: `ModelWorks/_2_blender_f1-helmet-lando_2025championWinner/texture/리뉴얼/native_multimap_test_v1/`

| 후보 | 글래스 입력 알파 | 용도 |
|---|---|---|
| clear | 0.035–0.085 | 깨끗한 유리, 낮은 얼룩 영향 |
| balanced | 0.09–0.21 | 첫 게임 비교용 시작값 |
| worn | 0.15–0.35 | 얼룩·넓은 하이라이트를 더 잘 확인하는 비교값 |

스폰서 띠와 인증 스티커는 세 후보 모두 알파 1이다.
모든 큰 텍스처는 4096×1024이고, DDS에는 13단계 밉맵이 있다.
DDS는 수치 보존을 위해 RGBA8 UNORM 무압축으로 만들었다.
디퓨즈 밉은 알파 가중 평균으로 검은 가장자리 번짐을 줄이고, 노멀 밉은 다시 정규화한다.
원본 PNG·모델·런타임 설정은 수정하지 않았다.

### 공통 설정

```text
shader = ksPerPixelMultiMap_emissive
alpha blend = Alpha Blend
alpha test = off
depth = Read Only
emAlphaFromDiffuse = -1
isAdditive = 0
useDetail = 0
detailUVMultiplier = 1
nmObjectSpace = 0
ksAlphaRef = 0
ksEmissive = 0, 0, 0
extColoredReflection = 0
```

`emAlphaFromDiffuse=-1`은 디퓨즈 알파를 읽은 뒤, 이 CSP 구현의 Fresnel 반사 알파를 적용한다.
`1`은 디퓨즈 알파를 각도와 관계없이 그대로 쓴다.
`0`은 노멀 알파를 쓰므로 현재 입력에서는 글래스가 다시 불투명해진다.
`isAdditive`는 재질의 Alpha Blend 모드와 다른 셰이더 변수이다.

**Gamma Fix를 쓰는 렌더 경로:** `material_balanced_gamma.ini`를 시작값으로 사용한다.
이 프로필은 ksAmbient/ksDiffuse=0.25, ksSpecular=1, ksSpecularEXP=255이다.
Fresnel은 C=0.282843, EXP=2.272727, Max=0.707107이다.
로컬 셰이더가 Gamma Fix에서 C/Max를 제곱하고 EXP를 2.2배 하기 때문에 보정한 값이다.
확인한 표본에서는 보정 후의 알파 각도 반응이 일반 경로와 일치했다.

**Gamma Fix를 쓰지 않는 경로:** `material_balanced.ini`를 사용한다.
ksAmbient/ksDiffuse=0.5, ksSpecular=1, ksSpecularEXP=255,
Fresnel C=0.08, EXP=5, Max=0.5이다.
이 값들은 인공 조명에서 만든 시작값이며 실제 Pure 노출·반사 큐브에 맞춘 최종 튜닝값은 아니다.

각 INI의 `[MATERIAL_0]`과 재질 이름은 템플릿이다. 현재 새 모델의 실제 EXT 재질에 옮겨야 한다.
`ksEmissive`는 벡터이므로 INI의 FLOAT3=0,0,0을 유지한다.
파일을 찾을 수 있도록 생성 DDS들을 해당 모델의 텍스처 검색 폴더에 배치한다.
새 EXT UV가 이 PNG의 UV 배치와 맞는지도 확인해야 한다.

### 현재 프로젝트의 렌더 경로

`realvisor.lua`의 `visorLayerDefs`와 `visorLayerDrawItem`은 EXT를 별도 사용자 셰이더로 그린다.
이 경로가 원래 네이티브 메쉬를 숨기는 동안에는 ksEditor 재질만 바꿔도 위 결과가 보이지 않는다.
게임 비교에서는 해당 EXT를 네이티브 재질로 그리는 경로를 사용하거나,
사용자 셰이더에 같은 색·알파·스페큘러·광택·반사 입력을 구현해야 한다.
현재 overlay의 band opacity/film alpha에 이 txMaps를 연결하는 것만으로는 동일한 효과를 얻지 못한다.
본 작업은 런타임 경로를 전환하거나 기존 E1/E2/E3/RainFX를 변경하지 않았다.

## GPU 검증 결과

실제 셰이더 실행과 float readback 23건: 후보/연결 비교 7건, 기본 조건 8건,
R/G/B 분리 6건, Gamma Fix 각도 표본 2건.

- 띠 알파: 1.0.
- balanced 글래스 표본: 입력 알파 약 0.0977 → 정면 출력 약 0.1679.
- 같은 표본을 약 68.8°에서 관찰: 출력 알파 약 0.2570.
- 노멀 알파를 쓰는 기본 모드: 같은 글래스 표본의 출력 알파 1.0.
- R=0/1 분리 표본의 스페큘러 RGB: 0 → 약 0.998.
- 같은 비정면 방향에서 G=0.05/1: 약 0.618 → 0.000230. 광택 지수가 커지면 하이라이트가 좁아짐.
- B=0이면 분리한 환경 반사 RGB는 0, B=1이면 양수.
- 직접/앰비언트 조명과 환경 큐브를 모두 검정으로 하면 RGB=(0,0,0). 자발광 없음.
- 출력에서 NaN/Inf 없음. 원본 파일 SHA-256 변경 없음.

비교 이미지: `docs/diagnostics/2026-10-11/native-visor-material/comparison.png`.
`balanced_gamma_preview.png`는 인공 조명 아래에서 투명 글래스·불투명 띠·표면 얼룩을 보여준다.
배경 체크는 투명도를 확인하기 위한 것이며 실제 얼굴 렌더가 아니다.
알파 합성은 읽어낸 셰이더 출력으로 계산했다. 게임의 투명 정렬·깊이 동작을 검증한 것은 아니다.
`validation.json`, 컴파일 로그, RGBA32F 출력에 상세 수치를 보존했다.

소스 근거:

- `acc-shaders-master/recreated/ksPerPixelMultiMap_emissive_ps.fx`: 입력 샘플링, 알파 선택, emissive 경로.
- `acc-shaders-master/recreated/include_new/base/utils_ps.fx`: considerDetails, applyTxMaps, getReflParams, calculateReflection.
- `acc-shaders-master/recreated/include_new/base/_gamma.fx`: Gamma Fix 수치 변환.

재현:

```powershell
& 'C:/Users/songak/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' docs/tools/test_visor_native_multimap.py
```

원본이 동일하고 생성 자산이 존재할 때 `--gpu-only`로 GPU 비교만 다시 실행할 수 있다.
