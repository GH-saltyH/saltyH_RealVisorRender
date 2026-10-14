# RainFX s76 — P1 SI GPU 코어 함수와 관성 검증

Date: 2026-10-14. Status: REFERENCE — shared GPU core 구현/검증 완료. persistent state 연결은 s77의 opt-in 프리뷰로 구현됨.

## 구현

`shaders/rainPhysicsSI.hlsl`에 P1의 물리 코어 함수를 작성했다.
저장 부피 mm³에서 SI kg를 산출하고, 식 내부의 거리·속도·힘은
metres/m/s/newtons로 계산한다. 표시 크기·texel·legacy UV reference는
함수 입력에 없다. 작은 방울과 큰 방울의 질량은 실제 D³ 비율을 가진다.

- 공중 equivalent D ↔ 부피, 질량, 부착 spherical-cap radius/height.
- static/dynamic contact-angle hysteresis의 pinning N을 따로 계산.
- attached cap의 입사 방향별 exposed-area 항력 근사. 스치는 바람을
  incidence gate로 0으로 만드는 방식은 사용하지 않는다.
- 실제 중력·world 관성을 질량으로 힘으로 환산하고 같은 표면에 투영.
- 점성 이동 저항은 `c=shapeCoefficient × mu × contactWidth` kg/s.
- stiff drag는 exponential response로 적분하고 contact friction은
  proximal update로 속도를 0에서 멈춘다. 반대 방향으로 튀지 않는다.
- D^0.67 낙하 속도 유래 surface cap, normalized mass 1–9, 전역
  acceleration gain은 이 함수들에 없다.
- SI Jacobian의 raw UV↔world velocity 변환, 동종 물의 volume-weighted
  병합 운동량 함수.

material theta/R/A/dynamic R/A, shape coefficient, viscosity, density,
surface tension 및 attached Cd는 explicit 입력이다. 실제 재질에 대해
보정한 값이라고 간주하지 않는다. local air는 차폐를 적용할 입력이며
surface drag와 air incidence의 근사에는 CFD 정확도를 주장하지 않는다.
primitive는 정상적인 unit normal/양의 물성을 요구한다. 설정/bake의
validation은 후속 controller binding에서 담당한다.

## 사용자 G 실측 반영

정차 raw G=0, 가속 Z>0, 제동 Z<0 결과에 따라 P0 adapter의 G convention을
`excludes gravity (P0 observed)`로 기록했다. world inertial acceleration은
raw world acceleration의 부호를 한 번 반전한 값이다. geometry plane에
투영하기 전 별도 gravity와 합산한다. angularVelocity의 단위는 아직
확인되지 않아 회전 관성 항은 추가하지 않는다.

## 검증

`docs/tools/check_s76_si_core.py`가 실제 shared HLSL을 **FXC ps_5_0
/Ges /WX**로 컴파일하고 D3D11 WARP의 float 결과를 읽었다.

| 검증 | 결과 |
|---|---|
| .1–6.3 mm 부피·질량·θ90 contact cap | analytic 값 일치 |
| contact-angle pinning N와 normal Weber | 단위/수치 일치, zero hysteresis 저항=0 |
| 작은 방울의 gravity-only pinning | 정지 유지 |
| friction-free g+inertia | .01s 결과 (.05,-.0980665,0) m/s |
| 사용자 가속·제동 world 관성 입력 | 반전 1회 및 표면 법선 방향 가속 취소 확인 |
| stiff viscous drag | analytic 값 약 .0684401 m/s 일치 |
| friction으로 정지/체적0 | 반전/NaN 없음 |
| grazing air / normal pressure | grazing 항력 유지, normal-only tangential force=0 |
| 병합 | volume·동종 물 momentum 보존, 접촉 반경³ 상한 없음 |
| UV skew/remap 및 표시 gain .25/.5/1/2 | 물리 결과 불변 |

검증 중 compiler가 상수 c=0 분기에서도 division-by-zero를 진단했다.
분모를 명시적으로 보호하고 모든 시험을 /WX로 다시 통과시켰다. 이 보호는
양의 정상 물성 결과를 바꾸지 않고 null/zero diagnostic에 유한 결과를 준다.

`si_core_checks.json`에 함수 source SHA와 결과를 저장했다. 실제 앱의
GPU timing, 재질 튜닝, 입사 충돌 분포, rendering look은 아직 이 시험의
검증 범위가 아니다.

## 다음 연결 단계

1. versioned meta의 authoritative V와 age/generation을 연결한다.
2. transport가 SI velocity를 metric으로 raw UV에 변환하여 경계-safe 이동한다.
3. birth/merge/film에 같은 volume 원장을 사용하며 물리/표시 radius를 분리한다.
4. scene binding과 material/weather uniforms의 공통 key·texture budget을 검증한다.
5. P2 virtual impact/DSD와 P3 보존되는 deposit을 연결한 기본 모델을 평가한다.

후속 s77에서 shared library를 persistent GPU state에 연결했다.
`RAINFX_S77_SI_MOTION_PREVIEW.md`의 opt-in 운동 프리뷰를 따른다.
primitive 검증을 P2/P3를 포함한 전체 모델 완료로 보고하지 않는다.
Smear/local impact film의 새 모델 의존성은 추가하지 않았다.
