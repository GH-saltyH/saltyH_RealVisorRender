# RainFX s80 — P2 게임 결과와 병합 보존 오류

Date: 2026-10-15. Status: ACTIVE — s79 게임 결과 반영, SI 병합 오류 수정 및 오프라인 검증 완료. 수정 빌드의 게임 원장 재검증 필요.

## 1. User result

사용자는 s79에서 P1 및 P2를 모두 켜고 같은 세션에서 검증했다.
Heavy Rain 톤/구름, 약 60% rain, wetness .6, water 1, RH .8,
air 22°C, road 18°C, wind 약 14.8 km/h, mist 0이다.
실제 로그의 liquid intensity는 .608979였다.

같은 정차 장면의 FPS:

| 조건 | FPS |
|---|---:|
| 앱 OFF | 91–94 |
| P1만 ON | 72–73 |
| P1+P2 ON | 72–73 |

전체 앱의 추가 프레임 시간은 범위 끝값으로 계산하면 **2.710–3.251 ms**다.
이번 측정에서는 P2의 추가 비용이 구분되지 않는다. P2만의 GPU 시간이 0이라는 뜻은 아니다.
주행 성능은 별도로 측정되지 않았다. s77의 93/71/76과 다른 관찰이므로 기록을 덮어쓰지 않는다.

P0 정차 snapshot(frame703049)은 car speed/G/inertia=0, wind=(-.1266,0,4.6233)m/s였다.
주행 snapshot(frame716336)은 speed37.976m/s(약136.7km/h), air=(32.8823,.7498,-14.4971)m/s,
inertia=(8.39273,-1.28561,-4.03712)m/s²였다. 두 snapshot 모두 inertia verified,
G excludes gravity, rotation unverified, invalid/capped=0이었다.
P0 snapshot과 아래 원장 frame은 다르므로 동일 순간의 공급량으로 취급하지 않는다.

| 누적 원장 / mm³ | 정차 frame710668 | 주행 frame723626 |
|---|---:|---:|
| input | 4476.677734 | 13793.625000 |
| film reserve | 514.779907 | 1832.923340 |
| micro reserve | 349.602966 | 1487.909912 |
| bounce | 1368.951050 | 5287.489258 |
| capacity | 85.293922 | 166.471283 |
| exit | 1575.328369 | 4998.470703 |
| 현재 drop inventory | 587.053528 | 22.264177 |
| residual | **-4.332008** | **-1.903673** |
| 누적 arrivals | 432 | 1769 |

면적은 .040289m²였다. residual/input은 각각 -.09677% / -.01380%다.
잔류 방울은 현재 inventory이고 다른 항목은 누적값이다. 주행 열도 정차 구간을 포함할 수 있다.
현재 원장에는 시작부터 성공적으로 시뮬레이션한 시간이 없어 관측 초당 유입량을 계산할 수 없다.

사용자의 관찰:

- P1만 ON은 이미 채워진 표면에서 시작하고 정차 중에는 새 birth가 거의 없다.
- P2는 빈 표면에서 시작한다. 정차·정면 시점은 방울이 성기며,
  상단/볼록 스티커 부근에서 굴러 커진 방울이 내려오는 것으로 보였다.
- 하늘을 향하면 더 많은 방울이 부착·누적되는 것으로 보였다.
- 고착된 방울은 유지되고 이동 방울은 사라진다. P2의 이동이 더 빠르게 보인다.

네 영상 모두 메타데이터 및 각 8개 시각의 원본 프레임을 확인했다.
`diagnostics/2026-10-15/s80/frames/metadata.json`에 파일·시각·해상도·프레임률을 기록했다.
P1/P2 내부 시점의 밀도 차이와 외부 시점의 성긴 방울은 확인된다.
외부 영상은 바이저가 어둡고 압축되어 작은 방울의 실제 부착 개수, 개별 병합과
퇴장 원인을 영상만으로 확정하지 않는다. 기존 P1에서 보인 파편도 새 물리 분열의 증거는 아니다.

## 2. 성긴 표면과 방향 반응의 평가

P1은 occupancy/respawn으로 채운 표면이다. P2는 빈 표면에서 실제 면적·법선 입사로
공급받는다. 초기 밀도가 같아야 하는 비교가 아니다.

현재 설정의 estimated R은 **12.17958 mm/h**, DSD weights=(0,0,1,0),
number mean airborne D=**1.63625 mm**, volume-weighted terminal=8.28012m/s다.
이는 날씨를 실측한 값이 아니라 현재 s78의 교정 가정이다. CSP Heavy Rain 이름을
이 DSD 또는 특정 mm/h의 물리적 검증으로 취급하지 않는다.

정차 입력 및 incident-air fraction=.30에서 동일 면적을 **이상적인 평면**으로
계산하면 다음과 같다(실제 곡면 바이저의 측정 유입량 아님):

| 방향 | 입사 개수 /s | 입사 체적 mm³/s |
|---|---:|---:|
| 수평, 위를 향함 | 12.454 | 136.305 |
| 수직, 해당 바람을 정면으로 받음 | 3.393 | 22.832 |
| 수직, 해당 바람의 뒤쪽 | 0 | 0 |

따라서 하늘을 향할 때 누적이 증가하는 것은 모델이 실제로 예측하는 반응이다.
사용자의 영상 구도를 위 평면으로 단정하거나 실제 공급이 정확히 5.97배라고 주장하지 않는다.
곡면의 위쪽 법선/스티커 부근으로 공급이 치우칠 수 있으며, 가림은 아직 static exposure 근사다.

film+micro reserve는 입력의 **19.309% / 24.075%**다. 이 물은 아직 공간장/광학으로
출력되지 않는다. 주행 로그의 현재 head inventory는 입력 누계의 .1614%지만,
누적 bounce/exit와 섞인 비율이므로 정상상태의 즉시 부착률로 해석하면 안 된다.
capacity는 1.905% / 1.207%로, 전부 slot 부족 때문에 성긴 것이라는 근거는 없다.
micro 하한은 airborne D<.25mm이며 이번 tail seed는 .5mm부터여서,
여기서의 micro 대부분은 impact share다.

P3 film/micro/trail이 빠진 상태에서 전체 수막 표현을 최종 평가할 수 없다.
현재 빈 표면을 보상하려고 R/exposure, physical D 또는 display gain을 자동으로 올리지 않는다.
재질의 bounce/retention prior, source shielding 및 R 교정은 여전히 추정 단계다.

## 3. 더 빠른 이동의 평가

두 preview의 운동 solver 자체는 동일하다. P2는 더 큰 대기 DSD를 샘플링한 뒤
실제 retained V에서 접촉 반경을 계산한다. P1의 과거 작은 크기 프로파일과 같지 않다.
같은 재질에서 모델의 gravity/inertia는 V에, contact pinning과 viscous drag는
접촉 폭에 비례하므로 큰 retained 방울은 더 쉽게 움직이고 다른 응답 시간을 갖는다.

또한 P1의 합성 birth hold/ramp는 P2에서 제외되고, P2는 입사 접선속도×.015의
초기 impulse로 시작한다. 이 차이가 처음부터 빠르게 보이는 데 기여할 수 있다.
display scale=.40은 렌더링에만 적용되므로 화면상 작은 방울도 물리 체적이 클 수 있다.
현재 영상으로 retained D별 mm/s, numerical transport cap 퇴장과 실제 경계 퇴장을
분리할 수 없다. 정성 관찰을 운동 검증 통과 또는 새 마찰 계수의 실측으로 기록하지 않는다.
물성은 여전히 20°C 참조이며 local air/material 계수도 교정이 필요하다.

## 4. 재현하고 수정한 보존 오류

`rainMergeDecode`는 두 방울에 reciprocal command가 있어도 각자 자신의 위치에서
`rainMetricLength(selfP, partnerP-selfP)`를 계산했다. 곡면/삼각형 UV 척도가 다르면
같은 reach에 대해 한쪽만 승인할 수 있었다.

- survivor만 승인: partner V를 더하고 partner도 살아 있어 **물 복제**.
- absorbed만 승인: partner가 사라지고 survivor는 V를 받지 않아 **물 삭제**.
- 이미 boundary 밖인 partner를 stale command로 합침: exit에도 V가 기록되어 **이중 계상**.

실제 production state/meta HLSL 및 D3D11 WARP에서 세 경우를 재현했다.
작은 방울 .65mm의 V=.1437933mm³가 한 사건에서 복제/삭제/이중 계상됐다.
이 오류는 negative residual과 그 값이 이후 개선되는 방향까지 설명 가능한 원인이다.
다만 사용자의 원장 오차 전부가 이 세 원인이라고 확정하지 않는다.

SI 경로의 두 decoder(state/meta)를 함께 수정했다:

`pairDistance = max(distanceAtSelf, distanceAtPartner)`

서로 같은 거리와 같은 reach를 사용하고 **두 위치 모두 현재 supported boundary 안**이어야 한다.
보수적 endpoint 근사로 양쪽 판정을 일치시킨다. 정확한 곡면 geodesic이나 boundary 사이
경로 전체의 가림 판정은 아니며, 거리가 충분히 가까워질 때 병합을 허용한다.
P1 SI 병합에도 적용하고 기존 non-SI 병합은 변경하지 않는다.
사후 residual을 0으로 보정하거나 원장 항목을 재분배하지 않는다.

## 5. 비용·검증·설치

새 GPU pass, 캔버스, readback 또는 CPU 방울 루프는 없다.
SI merge command가 있는 decoder에서 partner metric과 두 boundary/support를 추가로 읽는다.
추가 texture load가 있어 비용을 0이라고 주장하지 않지만 전체 해상도 수막 blur보다 좁은 작업이다.
수정 후 게임 FPS는 아직 측정되지 않았다.

`check_s80_merge.py`: `/Ges /WX` 실제 state/meta/event WARP 검증.

- 기존 one-sided 복제/삭제: ±.143793mm³ → 수정 후 0.
- 기존 departed partner 이중 계상: -.143793mm³ → 수정 후 0.
- 실제로 가까운 pair의 병합 유지: V 오차 2.09e-7mm³.

`check_s80_regression.py`: 기존 s79 GPU 10개와 Lua wiring 13개 검사 통과.
기존 결과 파일을 덮어쓰지 않고 s80 아래에 보관한다.
P2 OFF/P1 기본 entry, birth source/partition, 4096 slots, 운동량, atomic publication,
pending/readback epoch 및 allocation reuse를 재검증했다.
튜닝 값, 물리 core, birth DSD/impact assets는 변경하지 않았다.

수동 P2 budget 로그에 `publishedSeconds`, `steps`, `intervalSeconds`,
`inputRate(mm3/s)`, `arrivalRate(/s)`, `residualDelta(mm3)`를 추가했다.
시간은 성공한 atomic commit에서만 더한다. pending/실패 재시도는 더하지 않는다.
첫 로그의 rate는 시작부터 평균, 다음 로그부터는 두 성공 snapshot 사이 평균이다.
비동기 callback에서 읽는 시간도 요청 시점의 snapshot으로 고정한다.
같은 시각의 중복 로그는 interval=0/rate=0이고, reset 시 clock·이전 로그도 지운다.
shader texture/uniform 계약과 수동 8-float readback은 변경하지 않았다.

`realvisor.lua`/shader는 기존 project 링크로 반영된다.
`rain_birth_gpu.lua`는 마지막 설치 hash를 확인하는 `install_s75_inputs.ps1`로 갱신한다.
**앱 reload 후** 새 decoder 및 clock을 사용한다. commit/push는 사용자가 한다.

## 6. 다음 gate

P2 보존 gate는 아직 완료가 아니다. 수정 빌드에서 같은 60% 조건의 정차와
100–150km/h 직진 각각 budget을 15–30초 간격으로 두 번 기록한다.
정차/주행 전환 직후의 첫 interval은 조건이 섞일 수 있어 구간을 안정시킨 뒤 비교한다.
P0 input snapshot도 함께 두면 방향과 공급 상태를 대조할 수 있다.

관측 residual 증가가 줄었는지, interval input/arrival rate가 타당한지 확인한 뒤
P3의 실제 공간 film·micro inventory와 trail/sheet로 진행한다.
보존 gate 확인 전 s79를 P2 전체 통과로 stamp하지 않는다.

결과: `diagnostics/2026-10-15/s80/{user_results,merge_checks}.json`,
`s79_gpu_regression/gpu_checks.json`, `s79_binding_regression/binding_checks.json`.
