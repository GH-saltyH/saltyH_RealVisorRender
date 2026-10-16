# RainFX s77 — P1 SI 운동의 persistent GPU 연결

Date: 2026-10-14. Status: REFERENCE — P1 운동 프리뷰 구현/오프라인 검증 및 게임 정성 검증 통과. 위빙 마찰 교정·주행 비용 및 P2/P3는 후속 작업.

## 1. 스탬프 범위

`codex/rainfx-physics-weather`, 게시 기준 `3975491`에서 P0(s75),
SI shared functions(s76), P1의 GPU 상태 연결(s77)을 진행했다.
사용자가 로컬에서 스탬프를 남긴다는 지침에 따라 자동 commit/push는 하지 않았다.

이번 단계는 **운동만 평가하는 opt-in P1 프리뷰**다.
`RAIN_PHYSICS_SI_PREVIEW=false`가 기본값이다. 새 DSD/입사 충돌(P2)과
보존되는 trail/film/micro/건조(P3)가 아직 연결되지 않았으므로 전체 모델
완성이나 최종 시각 결과로 평가하지 않는다.

## 2. 확인한 API와 실제 운동 연결

사용자 정차/가속/제동 로그에서 car acceleration은 gravity를 제외한
car-local G임을 확인했다. P0는 world 변환 및 부호 반전한 관성을 제공한다.
P1은 **중력 (0,-9.80665,0) + 이 world 관성**을 같은 접평면에 투영한다.
rotation units는 미확인이므로 회전 가속도 항은 도입하지 않았다.

P1 state/meta 의미:

| 채널 | 의미 |
|---|---|
| state RG | raw signed UV position |
| state BA | raw UV velocity; solver는 Jacobian으로 m/s 변환 |
| meta R | physical contact radius의 legacy reference 인코딩; 표시 gain 미적용 |
| meta G | **실제 액체 부피 mm³**; 1–9 normalized mass가 아님 |
| meta B/A | age 및 generation/status |

기존 profile의 diameter 값을 equivalent D로 해석해 V를 계산한다.
equilibrium contact angle은 프리뷰에서 uniform이다. material 코팅 값은
static/dynamic hysteresis span을 보간한다. 물의 density/viscosity/gamma는
이번 프리뷰에서 20°C reference이며 P2의 온도 물성 연결은 남아 있다.

solver는 mass=rho×V로 중력/관성/attached-cap air drag와 접촉 저항을
계산한다. legacy acceleration gain/adhesion profile/flow gain/size-derived
surface speed cap은 SI 경로에 적용하지 않는다. source enable bits는
기존 Forces 패널의 G/I/A checkbox를 사용한다.

local air fraction은 boundary-layer exposure의 **명시적인 추정 계수**다.
downward airflow 옵션은 원래 사용자 지침을 따른 local-flow 방향 근사로
남겼고, 물리적 중력/관성의 크기를 축소하지 않는다. 기상 wind는 Smear
축 옵션에서 가져오지 않고 P0의 world wind를 사용한다.

SI radius 및 birth G, survivor centre/momentum은 실제 부피에서 나온다.
동일 contact angle에서 병합해 부피를 더하며, legacy 2.5 mm display cap을
적용하지 않는다. absorbed/exit slot의 SI V는 0으로 정리한다.
기존 fixed age 및 rain-stop 2초 삭제는 SI에서 적용하지 않는다. 이 프리뷰는
아직 evaporation/film이 없으므로 pinned water가 지속될 수 있다.

## 3. 물리·표시 분리

`RAIN_PHYSICS_DISPLAY_DIAMETER_GAIN`은 GPU head의 **래스터 radius R**만
곱한다. state/meta radius, V, kg, pinning, 병합 후보 거리, 운동은 바뀌지 않는다.
θ=90° contact cap의 footprint 증가를 맞추기 위한 첫 기본값은
`2^(-1/3)=0.7937005259840998`이다. 같은 기존 equivalent-D profile을 쓸 때
이 값으로 이전 head footprint를 유지한다. P2의 더 실제적인 DSD는 별도로
표시 gain을 맞춰야 한다.

P1의 물리 velocity 변환은 raw Jacobian과 object-to-world matrix를 사용한다.
기존 `rainAdvance`는 1 mm 내부 step과 경계-safe 이동을 담당한다.
reference codec를 반/두 배로 바꿔도 같은 물리 결과가 나옴을 GPU 검증했다.
새 거리/힘 계산에 pixel scale을 섞지 않는다.

## 4. 프리뷰 경로와 제외 기능

프리뷰를 켜면 Smear, legacy local impact film, 기존 trail/wipe/splash
스탬핑 및 legacy micro/haze 표현을 배제한다. 새 physics와 GPU heads만
평가한다. 꺼진 효과를 CPU per-drop stamp loop로 fallback하지 않는다.

P0 liquid intensity를 초기/새 birth에 전달해 snow/sleet/hail 신규 액체를
막는다. current birth-size profile 및 occupancy/exposure는 P2 flux/DSD로
교체하기 전 임시 공급 경로다. 이것을 물리 강우율의 완성 구현으로 보고하지 않는다.

표시 모드 전환 시 기존 네 GPU bank를 dispose하고 schema에 맞게
재초기화한다. 이전 trail 이력도 제거한다. readback에 model epoch를
붙여 이전 모드의 비동기 결과를 retire/dispose한다. 초기 default OFF에서는
추가 mode reset을 만들지 않는다.

## 5. X4000와 엔트리 분리

state/meta의 `main`에서 X4000를 재현했다. P1을 넣기 전 baseline도
동일 warning이 있다. helper 단독 호출은 정상인데 복잡한 early-return
entry에서 compiler가 잠재 uninitialized 결과를 보고했다.

active entry를 다음 파일로 분리했다.

- `shaders/rainStateEntry.hlsl`: initialized result + single return.
- `shaders/rainMetaEntry.hlsl`: initialized lifecycle result + single return.

runtime은 Lua inline helper 부분만 취하고 새 entry를 붙여 컴파일한다.
inline의 이전 main은 비교용 기록이며 실행되지 않는다. 앞으로 entry
변경은 이 외부 파일에서 진행한다. warning suppression은 사용하지 않았다.

새 production state/meta 및 merge+wetpath macro variant가 FXC
`ps_5_0 /Ges /WX`로 통과했다. warning이 있던 archived reference만
비교용으로 /WX 없이 컴파일해 GPU 수치를 비교했다. 현재 production에
같은 예외를 적용한 것은 아니다.

## 6. 검증

`docs/tools/check_s77_binding.py`의 실제 HLSL D3D11 WARP readback:

- SI 가속도에서 .01s 후 UV (.5005,-.500980665), velocity (.05,-.0980665).
- reference codec ×.5/×2 물리 이동 불변.
- preview OFF: 기존 state/meta 출력 bit-identical.
- legacy init/waiting/eligible/respawn/active/expiry/dry-expiry 출력 bit-identical.
- rotated Jacobian에서도 world gravity/inertia 유지.
- meta G의 actual V, 접촉 radius 재계산, display gain .25–2 물리값 불변.
- paired merge의 V/momentum 보존, absorbed slot V=0, display cap 미적용.
- production merge+wetpath macro 동시 컴파일, SI의 legacy wetpath steering 차단.

LuaJIT actual wiring:

- shared SI uniform key와 두 parameter set의 vector 재사용(4개).
- 모드 전환 4-bank disposal 및 중복 reset 없음.
- model epoch 이전 readback retirement/dispose.
- GPU heads가 성공해야 프리뷰를 publish하며 CPU stamping에는 들어가지 않음.
- 전체 realvisor.lua syntax 통과.

settings, 기존 rain_surface/rain_trails와 기존 shader 파일은 s77 baseline
SHA 불변이며, 새 entry와 common library는 game shader 링크에서도 SHA가
일치한다. `checks.json`과 `source.diff`에 결과를 기록했다.

### User result — 2026-10-14

Heavy Rain 톤/구름, I=.60, track wetness=.60, track water=1.00,
RH=.80, mist=0, air 22°C / road 18°C, ambient wind 14.8 km/h / direction 0.
동일 정차 장면의 사용자 측정:

| 상태 | FPS | 1000/FPS, ms | 앱 OFF 대비, ms |
|---|---:|---:|---:|
| 앱 OFF | 93 | 10.753 | — |
| 앱 ON, P1 OFF | 71 | 14.085 | +3.332 |
| 앱 ON, P1 ON | 76 | 13.158 | +2.405 |

P1이 이 장면에서 약 .927 ms 빠르다. 단일 정차 장면의 전체 앱 비교이며
SI solver만의 GPU 시간이나 주행/4096-slot stress 결과로 해석하지 않는다.
프리뷰에서 legacy film 등도 빠지므로 차이를 전부 SI 운동의 효율로 돌릴 수 없다.

- 정차 고착, 큰 방울의 더 이른 이동 시작, 작은 방울의 강한 고착을 관찰했다.
- 직진 표면 흐름 및 횡가속/역방향 운동의 점진적인 방향 변화가 납득 가능했다.
- 기울어진 영역에서 더 쉽게 이동하는 경향을 관찰했다.
- display gain .460 및 1.5에서도 이동 민감도/전체 패턴이 비슷했다.
  정성적 지지이며 정확한 동일 궤적/병합 비교는 아니다. 수치 불변성은 WARP로 검증했다.
- 130 km/h 위빙에서 일부 큰 방울, 특히 중앙의 즉각적인 지그재그/정지가 남는다.

현재 θ=90°, viscous shape=80에서 `tau=m/c`,
`c=shape*mu*contactWidth_m`. 20°C, D_eq=.65 mm는 tau≈2.19 ms,
1.15 mm는≈6.84 ms, 2.25 mm는≈26.20 ms다. 기존 작은 크기 프로파일은
한 프레임보다 짧은 완화 시간을 만들며 새 힘에 빠르게 따라간다. kinetic pinning의
proximal zero clamp도 힘 반전 때 정지할 수 있다. 따라서 관찰은 적분식과 일치하는
후보 원인이 있지만 영상 궤적을 직접 분석하거나 실제 접촉선 마찰을 교정한 결론은 아니다.
P2의 실제 airborne/retained 크기 분포 및 재질/점성 교정 후 재평가한다.
display gain으로 물리 inertia를 보정하지 않는다.

**P1 판정:** 기본 고착·운동 방향 및 display/physics 분리의 게임 정성 검증 통과.
빠른 방향 반전/마찰 교정과 주행 비용은 열린 항목이다. 사용자는 FX를 검토할 수
있었으며 별도 startup/compiler 로그를 제공하지 않았다.

## 7. 사용 및 다음 단계

앱 reload 후 **RainFX → Weather inputs and physical units (P0)**에서
`Enable P1 SI motion preview`를 켠다. GPU heads가 필요하며 모드 전환은
rain state를 reset한다. 프리뷰 OFF는 기존 경로로 돌아간다.

먼저 정지/주행에서 고착·이동·코팅 경계·가속/제동 반응을 관찰한다.
표시 gain을 바꿔도 이동·병합이 달라지지 않아야 한다.
material/air/viscous 값을 프리뷰 패널에서 구분해서 평가한다.

후속 구현은 P2의 DSD/물 공급/virtual impact/온도 물성과 P3의 같은 V
원장을 쓰는 deposit/film/micro/건조다. 현재 P1에서 film/trail이 없는
것은 미구현 단계를 숨겨 보여 주는 보정 효과를 쓰지 않기 위한 범위다.
