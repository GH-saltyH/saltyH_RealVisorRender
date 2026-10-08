# 하우징: 엔진 멀티맵 렌더 경로

## 구현 방향

러버·패브릭·프레임을 일반 장면의 ksPerPixelMultiMap 재질로 렌더한다.
커스텀 HLSL에서 엔진 라이팅을 근사해 합성하는 방식에서 분리했다.
E1 lit 소스도 같은 세 메쉬의 엔진 재질을 GeometryShot으로 캡처한다.
이 경로는 엔진의 실제 셰이더를 사용하므로 연구용 acc-shaders-master 코드를
프로젝트 의존성으로 가져오지 않는다. 설치된 CSP의 구현과 연구용 스냅샷이
비트 단위로 동일하다는 뜻은 아니다.

각 메쉬는 ensureUniqueMaterials로 다른 메쉬/유리의 DUMMY 재질과 분리한 뒤
applyShaderReplacements로 교체한다. 원래 UV와 normal/diffuse/maps 파일을 유지한다.
프레임·러버는 Maps 파일이 없어 중립 Maps를 쓰고, 러버 diffuse는 기존 회색 값을 쓴다.
없는 디테일·AO 텍스처를 새로 생성한 것은 아니다. 기본 multimap과 emissive 버전은
공통 조명/반사 구조를 사용하며, 이 세 재질에는 발광 맵이 없어 기본 버전을 선택했다.

## 조명과 그림자

- 화면 하우징: 엔진의 일반 장면 패스에서 opaque/depth-write로 렌더.
- E1 lit capture: 같은 원본 재질 참조, setOriginalLighting(true), ShadersType.Main,
  setAlternativeShadowsSet('dedicated'), HDR 캡처.
- 기존 custom helmet 방향 마스크, sun bounce, 프레임 평균 ambient,
  shadow probe의 밝기 나눗셈은 native 하우징의 조명에 사용하지 않는다.
- shadow probe 생성/표시/복사 경로는 native 모드에서 차단.
- Source mode 1 opening weight는 진단 값이며 native 재질 조명에 곱하지 않는다.
- E1의 상대 밝기 선별과 프레넬은 반사 합성 단계에 유지.
- INT/EXT/COATING/RainFX는 기존 커스텀 렌더 경로와 순서 유지.

엔진 자원이 연결되는 경로를 마련했지만 게임의 실제 shadow caster와 지역 조명
적용 범위는 아직 확인하지 않았다. 따라서 지역 조명/그림자까지 완성됐다고
단정하지 않는다. Dedicated shadow set의 비용도 게임 측정이 필요하다.

## 조작

Housing 머티리얼 팝업의 `Housing: native engine multimap` ON이 기본이다.
Native 전용 ambient/diffuse/specular/gloss/Fresnel 슬라이더를 제공한다.
Specular/gloss는 기존 재질별 값에서 시작하고, exponent는 4+252×gloss다.
이 값은 레퍼런스의 ksSpecularEXP에 넘기며 맵 G 적용은 엔진이 한다.
Fabric specular가 기존 0이면 기본 specular 하이라이트는 약하거나 없을 수 있다.

OFF는 저장한 원래 shader replacements 설정을 복원하고 기존 커스텀 경로를 선택한다.
원본 설정은 세션 내에서 보존한다. 원본 KN5 파일은 수정하지 않았다.
Native와 legacy 조명을 동시에 합성하는 경로는 없다.

## 평가 항목

1. 리로드 후 native ON에서 FRAME/RUBBER/FABRIC 모두 보이고 유리·물방울도 유지되는지.
   status가 error이거나 세 메쉬 중 일부만 보이면 해당 문구와 화면을 전달한다.
2. 낮: 빛 정면/비스듬한 방향/빛 반대에서 재질 음영과 normal 디테일을 각각 확인.
3. 외부 가림: 트랙 건물/그늘 진입에 따라 하우징의 실제 그림자가 반응하는지.
4. 밤: 트랙 지역 조명 근처와 멀리 떨어진 곳을 비교. 태양 방향만 따라 켜지는지,
   지역 조명에 재질과 E1 source 모두 반응하는지 확인한다.
5. Source 0 / Primary 3: 화면 하우징과 같은 재질 특성이 캡처/반사에 나타나는지.
   같은 재질도 서로 다른 관찰 방향이면 specular가 달라지는 것은 정상이다.
6. Source 2 체커로 전환했다 돌아왔을 때 원래 lit 소스와 normal main 패스가 복원되는지.
7. 기존 가상 helmet/bounce/probe 수치가 native 하우징을 바꾸지 않는지.
8. Native ON/OFF 전환 시 누락/중복 하우징, INT/EXT 가림 회귀, OFF 재질 복원 확인.
9. 같은 시점의 frame ms: dedicated capture와 native 하우징의 비용 확인.

## 로컬 검증

- 전체 realvisor.lua LuaJIT 문법 통과.
- Lua mock: 세 메쉬의 재질 고유화/독립 텍스처, native shader 지정,
  native 하우징과 custom 유리의 draw/hide 집합 분리 확인.
- Native 설정 갱신 캐시, OFF 원래 shader 복원, ON 재진입 확인.
- Native E1 캡처의 Main/original lighting/dedicated shadows 요청과
  HDR 해상도·metric depth 캡처, 해상도/모델 세대 변경 시 재할당 확인.
- 게임 내 native 셰이더 출력과 그림자/조명 반응은 평가 대기.

## 로컬 API 근거

lib.lua: SceneReference.applyShaderReplacements, ensureUniqueMaterials,
GeometryShot의 reference 입력, setOriginalLighting, setShadersType,
setAlternativeShadowsSet, render.ShadersType.Main 설명을 확인했다.
render.mesh는 custom shader 전용이므로 해당 경로에 엔진 shadow/cubemap을
가짜로 연결하는 대신, native 메쉬를 엔진 일반 장면에 맡긴다.
