> 2026-10-09: 아래는 보존한 개발 기록이다. 현재 사용 경로는 [KN5 원본 네이티브 하우징](HOUSING_BAKED_NATIVE.md)이며 자동 재질 교체와 custom scene output은 비활성화했다.

# 하우징: 엔진 멀티맵 렌더 경로

## 구현 방향

러버·패브릭·프레임의 ksPerPixelMultiMap 재질을 엔진 HDR 캡처로 계산한다.
기본 `RAIN_VISOR_LAYER_NATIVE_SCENE_PASS=true`에서는 일반 KN5 색상 패스를
숨기고 실제 하우징 메쉬를 기존 custom scene stack의 opaque/depth-write로 출력한다.
캡처와 메인 카메라의 상대 위치·view/projection으로 색상을 재투영한다.
광원 계산은 native, 메인 출력은 custom이다. UI/HUD 후합성은 사용하지 않는다.
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

- 화면 하우징: 메인 렌더 타깃 크기의 engine HDR 캡처 → 실제 메쉬의 custom
  opaque/depth-write. 캡처는 onSceneReady에서 갱신하며 draw 안에 중첩하지 않는다.
- `Housing: custom scene output` OFF는 비교용 일반 KN5 출력이다.
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

## DRIVER_FACE / DRIVER_BALAKLAVA 사전 연결

현재 로드한 visor 아래에서 정확한 두 이름을 찾는다. 없는 메쉬는 정상적으로
건너뛰며 새 KN5를 리로드하면 다시 찾는다. 원래 셰이더/텍스처/UV는 교체하지 않는다.
일반 화면의 원본은 숨긴다. Native E1 색상 캡처에서는 별도의 KN5 인스턴스를
같은 axisRollNode 아래에 등록한다. 프레임 준비에서 보이게 하고 main.root.opaque에서
숨긴다. 원본 재질과 루트 local 자세를 공유/동기화하며 상위 변환 계층을 따른다.
원본 동명 메쉬를 metric depth 캡처에도 포함한다.
Source 2 checker에서는 얼굴은 주황, 발라클라바는 보라로 구별한다.
Native E1 색상 캡처는 transparent pass도 켜서 원본 alpha 재질을 지원한다.

얼굴은 화면 하우징용 캡처에 포함하지 않는다. 기본 captured-depth 반사 경로가
연결 대상이며, 보전된 actual-housing BVH 진단 데이터에는 얼굴이 없다.
Legacy custom lighting OFF/ON 비교 경로에서 얼굴의 원본 엔진 피부 셰이더를
재현하는 것은 이 연결의 대상이 아니다. Native ON으로 평가한다.

## 뒤쪽 하늘/광원에 따른 내부 과다 밝기 검토

`OriginalLighting`은 엔진의 sky ambient와 reflection까지 가져온다. 로컬 API에
명시된 대로 이 모드에서는 GeometryShot의 ambient/reflection colour 변경이 무효다.
Dedicated shadows를 요청하는 것만으로 내부 skylight 차폐가 보장되지는 않는다.
캡처 대상은 선택된 하우징/얼굴이며, 실제 헬멧 외피·뒤쪽 차폐 메쉬가 존재하고
shadow set에 참여하는지는 게임 확인이 필요하다. CullNone/양면 메쉬의 normal과
불완전한 폐쇄 형상도 직접광 누출의 후보다.

`Lighting diagnostic: direct diffuse only`는 하우징 ksAmbient, ksSpecular,
fresnelC/Max를 0으로 내려 원인을 구분한다. OFF에서 원래 slider 값으로 복원한다.
얼굴 원본 재질에는 적용하지 않는다. 이것은 해결용 방향 마스크나 fake shadow가 아니다.

- ON에서도 뒤쪽 태양을 따라 밝아짐: 실제 직접광 shadow/caster/normal 검토 필요.
- ON에서 현상이 사라짐: ambient/reflection 기여가 원인 후보. 실제 공간 차폐가
  필요하며 완성 색상에 단일 opening 마스크를 곱하면 피부/지역광/반사까지 잘못 억제된다.
- native 엔진의 해당 광원 항만 공간별로 조절하는 API는 확인되지 않았다.
  차폐 형상과 native shadow 반응을 먼저 검증하고, 불가능한 부분은 별도 재질 계산
  설계가 필요하다. 이번 변경으로 후면광 문제가 해결됐다고 주장하지 않는다.

## DLSS 평가

기존 기록의 안정적인 custom mesh 장면 출력 경로로 하우징 색상 출력을 옮겼다.
엔진 재질 계산과 출력 패스는 분리됐지만 API에서 velocity를 직접 작성하는 것은
여전히 불가능하다. 모션 벡터 문제의 완전한 해결/DLSS 안정성은 게임 평가 대기다.
프레임 간 카메라/메쉬 변형, 캡처 경계, 해상도 및 전용 shadow 캡처 비용도 확인한다.
노멀·specular 자체의 aliasing까지 이 패스 변경으로 제거되는 것은 아니다.
캡처 실패 시 stock KN5를 자동 노출하지 않고 status를 표시한다.

1. Native ON / custom scene output ON에서 재질·유리·EXT와 하우징 깊이 가림 확인.
2. 같은 위치에서 custom scene output OFF/ON 비교, DLSS 켠 채 머리·차량 이동 확인.
3. 뒤를 하늘로 향하는 자세에서 direct diffuse only OFF/ON 비교.
4. 새 KN5 투입 후 두 actor가 메인에서 숨겨지고 Source 0/2/3 및 Primary 3에
   색상/체커/깊이가 연결되는지 확인. actual housing BVH validation은 OFF로 둔다.
5. 화면 캡처는 프레임 타깃 크기이며 E1 source FoV/offset과 독립적으로 유지되는지 확인.

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
가짜로 연결하는 대신, native 엔진 캡처 결과를 custom scene 메쉬에 적용한다.

추가 검증: `docs/tools/check_housing_scene_pass.py`에서 전체 LuaJIT 문법,
optional actor 부재/발견, 캡처 성공/실패의 가시성 복원, main capture 설정과 resize,
custom draw 실패 시 숨김 복원, 출력 셰이더 FXC ps_5_0 컴파일을 확인한다.

## 검정 캡처 / Visible 토글 순간 출력 수정

사용자 관찰: 일반 출력은 검정이며 Visible을 토글하면 순간의 밝은 재질만 나타나고
연속 갱신되지 않는다. 기존 경로는 숨겨진 원본으로 GeometryShot을 생성한 뒤
update 동안만 가시성을 토글했다. 실제 엔진의 캡처 목록/가시성 갱신을 Lua mock이
재현하지 못했고, 이 방식으로 정상 게임 캡처가 검증된 것은 아니었다.

수정: 같은 KN5를 실제로 한 번 더 로드한 뒤 `setParent(nil)`로 장면에서 분리한다.
이 detached 인스턴스의 선택 메쉬는 프레임 사이에도 보이는 상태로 유지한다.
`SceneReference:clone()`은 메쉬 복제가 아니므로 이 용도로 사용하지 않는다.
원본 준비된 재질을 `assignMaterialFrom`으로 공유하고, 원본 KN5 root world matrix를
분리 root local matrix에 매 프레임 복사한다. 색상 캡처는 detached refs로 생성한다.
메인 하우징 캡처와 E1 native 색상 캡처 모두 같은 인스턴스를 사용하며 두 shot은
각자의 카메라로 갱신한다. 일반 장면에 clone이 중복 표시되지 않는다.

머티리얼 UI에 live 캡처의 C/(1+C) 프리뷰와 update 횟수를 추가했다.
이 프리뷰의 밝기는 장면 노출과 같지 않으며, 장면 재질의 밝기 튜닝 기준이 아니다.
리로드 후 Visible 토글 없이 count/preview/메쉬 출력이 계속 갱신되는지 확인한다.
프리뷰가 검다면 native 캡처, 프리뷰만 정상이라면 메쉬 재투영/출력 단계가 다음 조사 대상이다.

로컬 검증: detached KN5 생성/분리, 원본 숨김과 capture copy의 지속 가시성,
재질 공유, 연속 자세 갱신, capture resize/disposal, LuaJIT/FXC 통과.
게임 내 검정 출력 해소와 DLSS 이동 안정성은 사용자 재평가 대기다.

## 후속: detached 캡처도 검정 — registered root 경로로 교체

사용자 screenshot은 updates 24643에도 live 캡처가 검정임을 보여준다.
즉, API update 성공/횟수 증가가 실제 픽셀 렌더 성공의 증거가 아니었다.
위 detached 방식은 실패한 실험으로 보전한 기록이며 현재 경로가 아니다.

현재 수정은 같은 axisRollNode 아래에 하우징용/반사용 KN5를 각각 등록한다.
script.update 시작에 root 가시성을 준비하고 원본 local transformation을 복사한다.
이후 기존 상위 hierarchy 갱신을 따라 엔진이 world transformation과 render 목록을
계산하도록 한다. onSceneReady에서 두 native shot을 갱신하며 GeometryShot 참조는
개별 메쉬 union 대신 선택 메쉬만 활성화한 KN5 root를 전달한다.
main.root.opaque/mirror.track.opaque에서 capture root를 숨겨 중복 출력을 막는다.
반사용 root에만 얼굴/발라클라바를 포함하므로 하우징 캡처와 actor 가시성은 독립이다.

새 status는 `Registered root HDR capture`다. Live preview가 리로드 이후 지속적으로
나타나는지 먼저 확인한다. 이번 로컬 검증은 등록 root 준비/숨김 단계와 material/pose
연결 및 문법/컴파일을 확인한 것이며, 엔진이 실제 픽셀을 생성했음을 검증하지는 못한다.

## 사용자 평가: registered root 성공 / 차폐는 미해결

2026-10-08 사용자 확인:
- native와 같은 톤의 하우징이 지속적으로 갱신된다.
- 이 테스트에서 DLSS 일렁임이 없어졌다.
- custom scene output 추가 비용은 약 1.6 FPS (사용자 측정).
- direct diffuse only 진단에서도 개구부 밖에서 오는 빛이 남는다.

따라서 출력 경로는 확인된 기준으로 유지한다. 직접광 진단은 차폐 구현이 아니다.
Ambient/reflection만 제거해서 해결할 수 있다는 근거도 없다.

후속 코드 점검에서 copy.assignMaterialFrom만 호출하고 native 원본에 설정한
shadow/raster/depth 플래그를 capture copy에 명시하지 않은 누락을 확인했다.
캡처 하우징에도 setShadows(true), CullNone, opaque/normal depth를 적용했다.
얼굴에는 원본 alpha/렌더 상태를 유지하고 shadow casting만 활성화한다.
상태에 실제 isCastingShadows 확인 개수를 `shadow casters N/M`으로 표시한다.
이 수정은 그림자 참여/양면 상태를 일치시키는 것이며, 부족한 폐쇄 형상이나 엔진의
shadow receiving 제약을 해결한 것은 아니다. 후면 광원 반응은 추가 게임 검증 필요.

검증: LuaJIT 문법, capture copy 그림자/양면/opaque 상태와 caster count,
등록 root prepare/hide 및 기존 캡처 lifecycle mock 통과. 기존 출력 HLSL은 유지했다.
