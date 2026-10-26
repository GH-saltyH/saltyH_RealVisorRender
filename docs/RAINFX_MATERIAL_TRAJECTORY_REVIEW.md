# 재질 가설을 실제 메쉬의 짧은 운동·트레일 장면으로 연결

2026-10-25. 상태: offline 동작 비교 완료, 게임에는 시작 재질 readout만 추가.
미측정 재질값이나 수송 후보를 게임 기본값으로 채택하지 않았다.

## 비교 조건

- 실제 serial12343에서 유효하게 붙어 있던 방울 중 부피가 큰128개를 사용한다.
  위치와 물량은 보존하고 속도는0으로 초기화한다. 전체4096 슬롯의 대표 분포는 아니다.
- 실제 KN5 du/dv·경계 mask·캡처 자세를 사용한다. 처음 field/micro는 건조하다.
- 물리32Hz로1초를 진행한다. 중력만 적용하는 경우와 캡처한 순간의 공기·관성을
  고정 적용하는 경우를 비교한다. 후자는 정상 직진 조건이나 미래 리플레이 재현이 아니다.
- 새 birth/충돌/merge/pool·field 이동은 제외한다. head 증발은 포함하되 짧은 field
  증발은 생략했다. 이 장면으로 현재 거대 수막 누적이 해결됐다고 하지 않는다.
- 세 재질은 **현재 캡처한 bare/coat 대비**, 균일90°/20° 대조군,
  균일105°/8° 가설이다. 처음의 bare 대조군을 현재 전체 재질이라고 부르지 않는다.
- β=.15를 모든 경우에 공통 사용해 운동의 차이를 분리한다. 현재 실제 β.35/.05를
  그대로 재현한 실험은 아니다. 표현 gain을 물리 계산에 넣지 않는다.

## 재사용한 코드와 근사

힘 계산은 기존 `check_s148_heads.force_oracle`를 사용했다. 각 경우 첫/마지막 step을
실제 s148 motion HLSL과 비교했다. 매 step의 메쉬 이동은 실제 s148 trace와 제품의
bounded-walk 수정 HLSL을 D3D11 WARP에서 실행했다.
주변 자원/세대 context 검증만 trusted fixture로 대체했으며 물리/경계 walk는 유지했다.
실제 CSP 소유권·callback/clock 검증과 혼동하지 않는다.

head에서 떼는 체적은 현재 finite-drop deposit/evap 관계를 사용한다. field에 뿌리는
형상은 CPU 보존 Gaussian capsule 근사다. 실제 생산 raster와 동일한 그림임을
증명한 것은 아니다. 경계 밖 stamp 물과 head exit는 별도로 기록한다.

## 결과

초기 head 물량은 모든 경우11.2788035mm³다. 중력만의1초에서는 세 재질 모두
한 field 셀 이상 이동하지 않았다. 캡처한 힘을 고정한 결과는 다음과 같다.

|재질|한 field 셀 이상 이동한 방울|field에 남은 deposit|head exit|
|---|---:|---:|---:|
|현재 θ90°, static bare20°/coat4°|19/128|.51490mm³|1.22585mm³|
|균일 θ90°, static20° 대조군|0/128|0|0|
|균일 θ105°, static8° 가설|11/128|.42034mm³|1.66878mm³|

**'낮은 고착' 가설은 bare20° 대비 낮은 고착이지, 이미 coat4°인 영역보다 더
잘 흐른다는 뜻이 아니었다.** 실제 공간 코팅 대비를 넣기 전에 preset을 채택하면
반대로 더 강하게 붙게 만들 수 있다. 이 비교로105°/8°를 default로 채택하지 않았다.
모든 frame의 head+field+exit+증발+stamp 밖 물의 잔차는 최종 float64 합산에서0으로
표시됐다. 이는 제품 FP32 원장이나 모든 실행 환경의 정확한0을 보장하는 말이 아니다.

## 표시 해상도에서 드러난 제약

현재 재질362개 stamp 중304개, 가설175개 중173개가 지원 kernel의 최소 축에 걸렸다.
`pfSupport`는 축당 최소1field texel 반경을 가진다.1024×256 field에서4096×1024
authoring 기준으로는 축당4texels에 해당한다. 이것은 **수학적 support**이며
불투명한 선 폭이 항상8texels라는 뜻은 아니다. 실제 raster falloff는 별도로 봐야 한다.

물리 접촉 footprint와 head 표현 gain.31748을 쓰는 작은 방울은 이 support보다 작을 수
있다. 작은 체적이 넓은 지지 범위로 분배되면 높이/gradient가 약해져 가는 trail이
잘 보이지 않을 수 있다. 접촉각/마찰만 바꿔 이 공간 해상도 문제를 해결할 수 없다.
단순 upscaling이나 물리 직경/질량 확대를 해결책으로 삼지 않는다.

확대 optics에서도 효과는 매우 약하다. 현재 비교에 새 대량 공급이 없고,128개 subset의
trail만 있기 때문이다. 이 현미경 장면의 선명함을 목표 C/B/A 전체의 품질 통과로
취급하지 않는다. head/짧은 trail의 공통 표시 계약이 다음 표시 작업의 기준이다.
해상도 병목을 이유로 전체 field 해상도와 비용부터 올리지 않는다.

## 게임에 추가한 최소 변경

기존 P0 continuous preview에 시작 시 캡처한 θ, static/dynamic bare/coat span,
trail β bare/coat를 표시한다. 새 실험 앱이나 profile 자동 적용 버튼은 추가하지 않았다.
물리·기본값·GPU pass·자원·readback은 바꾸지 않는다. 앱 reload 후 같은 메뉴에서 적용된다.
재질은 시작에 고정되므로 변경하려면 reload가 필요하다는 설명도 표시한다.

## 산출물과 비용

- 실행: `docs/tools/run_material_trajectories.py`, `render_material_trajectory_scenes.py`.
- 결과: `docs/diagnostics/2026-10-25/material_trajectories/`.
- `whole_atlas_paths.png`: 전체 UV의 시작점/실제 native 경로. 점/선은 진단용 확대 표시.
- `linked_material_sequence.png`:0/.25/.5/1초의 동일 ROI optics 근사.
- `linked_material_final.png`: 같은 ROI의1초 비교. crop/배율은 명시된 현미경 시점이다.
- `review.json`: seed 선택,6조건, 물량/exit/deposit, 원시 NPZ와 제약.
- ROI는 가설의 최대 deposit 부근을 택한 후 모든 비교에 고정했다. 별도 전체 UV
  경로도 제공해 선택된 부분을 전체 장면처럼 해석하지 않도록 한다.

초기 대조군4조건 실행2회 후, 실제 coat 대비와 마지막 힘 검사를 포함한6조건으로
정리했다. 최종204native draws/2strict programs, 단계 전체468native draws다.
최종6초 상당의6조건 계산은 로컬 약46.9초였다. 게임 FPS 추정값이 아니다.
제품 회귀13그룹과 native optics8draws/3programs도 통과했다. 실제 CSP는 실행하지
않았으며 새 사용자 실험 요청은0회다. 모든 실행을 더 세밀한 수치 연구로 확대하지 않았다.
