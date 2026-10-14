# 외부 관찰용 강한 반사 COAT · 검정 틴트 EXT v3

## 적용

패키지: `ModelWorks/_2_blender_f1-helmet-lando_2025championWinner/texture/리뉴얼/GLASS_external_reflective_v3.zip`

| 대상 | 프리셋 | txDiffuse | txNormal | txMaps |
| --- | --- | --- | --- | --- |
| `mtGLASS_COATING` | `material_COAT_reflective.ini` | `COAT_reflective_diffuse.dds` | `COAT_smooth_normal.dds` | `COAT_reflective_maps.dds` |
| `mtGLASS_EXT` | `material_EXT_dark.ini` | `EXT_dark_diffuse.dds` | `EXT_normal.dds` | `EXT_dark_maps.dds` |

두 재질 모두 **ksPerPixelMultiMap_emissive**, Alpha Blend 켜기, Alpha Test 끄기, Depth Read Only다. `txDetail=neutral_white.dds`, `useDetail=0`, `txEmissive=neutral_black.dds`, `ksEmissive=(0,0,0)`을 지정한다. Gamma Fix 렌더 경로에는 각 `_gamma.ini`를 사용한다. `[MATERIAL_0]`은 템플릿이므로 실제 재질 이름에 해당하는 블록으로 옮긴다.

EXT를 먼저, 그 바깥의 COAT를 뒤에 합성하는 구성이 기준이다. 동일 위치의 중복 표면이나 반대쪽 면까지 함께 그려지면 불투명도가 누적된다. 비교 이미지는 이 두 층을 각각 한 번 합성한 결과다. INT의 실내 FX용 설정에는 이 외부용 EXT 틴트를 적용하지 않는다.

## 변경 내용

COAT가 주된 환경 반사를 담당한다. txMaps의 G와 B를 전체 면에서 1로 고정했다. 끝부분의 흐림과 문자는 디퓨즈/알파에 남기고, 반사 자체는 끝까지 선명하게 받는다. R은 약 0.902다. 균일 맵은 4×4 DDS로 줄였다. 기존의 큰 주름 노멀을 그대로 사용하여 접힘에 따른 반사 굴곡을 유지한다. 새 미세 노멀이나 grain은 만들지 않았다.

EXT는 전체 유리 부분의 입력 알파를 **184/255 ≈ 0.722**로 올리고 RGB를 **(4,4,4)** 검정 틴트로 만들었다. 띠와 배지의 색·불투명 영역은 기존 패턴을 통해 분리하여 보존한다. EXT의 자체 반사는 낮춰 COAT의 선명한 반사가 주도하게 했다. EXT 유리 구역의 txMaps는 약 `(0.40, 1.0, 0.25)`로 균일하다.

| 파라미터 | COAT | EXT |
| --- | --- | --- |
| ksAmbient / ksDiffuse | 0.08 / 0.12 | 0.15 / 0.20 |
| ksSpecular / ksSpecularEXP | 0.90 / 255 | 0.25 / 255 |
| fresnelC | 0.32 | 0.02 |
| fresnelEXP | 4 | 5 |
| fresnelMaxLevel | 0.85 | 0.16 |
| emAlphaFromDiffuse | -1 | -1 |
| extColoredReflection | 0 | 0 |

COAT의 C=0.32는 레퍼런스의 강한 반사 필름을 맞추기 위한 시각적 설정이며 투명 플라스틱의 측정된 굴절률을 뜻하지 않는다. 네이티브 셰이더의 환경 반사 결과가 Alpha Blend로 다시 약해지는 점을 포함해 설정했다. 지수 255와 G=1은 재질이 추가하는 환경 반사 블러를 없애지만, 실제 엔진의 큐브맵 해상도와 갱신 주기에 따른 선명도는 그대로 영향을 준다. 흰 라이트를 텍스처에 그려 넣은 결과가 아니다.

## 색상만 교체

출력 폴더의 `tint_settings.json`에서 `tint_rgb_u8`의 세 숫자만 바꾼다. 예를 들어 검정은 `[4,4,4]`, 어두운 갈색은 `[24,10,4]`다. 이후 프로젝트 루트에서 다음을 실행한다.

```powershell
& 'C:/Users/songak/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' docs/tools/build_external_reflective_glass_v3.py --tint-only
```

또는 `--tint-only --tint-rgb 24,10,4`로 직접 지정한다. `EXT_dark_diffuse.dds`만 다시 연결하면 된다. 알파·띠·배지·모든 다른 DDS가 동일한지 코드가 확인한다. 반사 색은 `extColoredReflection=0`으로 중립을 유지하며, COAT와 노멀·txMaps는 변경되지 않는다. 마스크 PNG도 포함했다. 단순 RGB 틴트 교체와 실제 다층 유리의 파장별 투과, 색이 있는 미러 코팅은 서로 다른 구현이므로 이 설정은 우선 검정/유색 틴트 교체를 제공한다.

## 검증

로컬의 실제 `ksPerPixelMultiMap_emissive` HLSL을 Legacy와 Gamma Fix 각각 컴파일하고 D3D11 WARP에서 실행했다. 합성 원통 UV와 HDR 스튜디오/색상 블록 환경으로 v2와 v3의 두 층을 비교한다. `comparison.png`는 실제 헬멧이나 게임에서 촬영한 이미지가 아니다.

검사 항목은 정면·60°·75°의 최종 알파, 두 층 뒤 배경의 잔여 기여, COAT의 흰 환경 반사 기여, 틴트 교체 시 중립 반사 유지, 원본 해시 보존 및 DDS 전체 mip/픽셀 일치다. 수치는 `asset_manifest.json`과 `docs/diagnostics/2026-10-11/external-reflective-glass-v3/validation.json`에 기록한다. `--tint-only` 이후 비교 PNG는 최초 검정 틴트 기준이며 갱신된 DDS/해시는 매니페스트에 반영된다.

균일한 중앙 유리 위치에 플랫 노멀을 적용한 셰이더 검사에서, 뒤 배경의 합성 기여는 v2 정면 **84.4% → v3 17.9%**, 60° **79.0% → 15.8%**, 75° **53.1% → 8.9%**였다. 이는 두 표면의 알파 합성 계수이며 물리적 유리 투과율 측정이 아니다. 동일한 흰 환경에 대한 COAT의 정면 합성 반사 응답은 **0.00154 → 0.10872**로 증가했다. 직접 조명을 끈 검사에서 틴트 RGB를 바꾸어도 두 재질의 중립 반사 RGB 차이는 0이었다. Legacy와 Gamma Fix에서 정면 알파도 일치했다.

원본 텍스처와 기존 v2, 현재 FBX 재질 설정을 덮어쓰지 않는 별도 패키지다. 실제 게임에서의 헬멧 투명 정렬 및 반사 환경은 사용자가 적용해 확인해야 한다.
