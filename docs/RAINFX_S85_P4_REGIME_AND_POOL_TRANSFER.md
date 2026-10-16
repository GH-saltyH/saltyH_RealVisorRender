# RainFX s85 — P4 수송 범위 진단과 보존적 고임 전환 원형

Date: 2026-10-15. Status: REFERENCE — 같은 프레임 자료로 P4a의 두꺼운 고임/준정상 수송 문제 확인. P4b GPU 전환 원형의 물 보존 검증 완료. **이 단계는 원형이며 실제 런타임 연결은 후속 s86 참조. P4 수송 시간 gate는 열려 있다.**

## 1. 이번 단계의 범위

사용자가 제공한 s84 정차/137km/h의 두 쌍은 각 쌍의 frame과 film 재고가
정확히 일치한다. 이제 추가 정차·주행 로그 없이 제한 질량의 비중을 계산할 수 있다.
원본은 `diagnostics/2026-10-15/s85/p4_paired.log`, 계산은
`tools/review_s85_p4_regime.py`, 결과는 같은 폴더 `regime_review.json`이다.

s84 전달 파일의 SHA가 그대로인 것을 확인하고 s85 baseline을 보존했다.
이번에는 게임 Lua/HLSL·설정·표시 크기·설치 파일을 변경하지 않았다.
P4b를 완성한 것처럼 불완전한 전환을 게임에 연결하지 않고,
`prototypes/s85_pool_transfer.hlsl`에서 실제 GPU의 후보/소유권/물 보존을 먼저 검증했다.

## 2. 사용자 결과의 수치 해석

| 지표 | 정차 frame495963 | 137km/h frame497992 |
|---|---:|---:|
| 현재 film/mm³ | 698.426270 | 819.854431 |
| 제한되는 젖은 셀 비율 | 0.6230% | 1.5242% |
| 제한 셀에 들어 있는 film 비율 | **49.0823%** | **44.8306%** |
| film 체적 가중 모델 속도 보존율 | 52.0827% | 59.7221% |
| 1mm 초과 두께 셀의 film 비율 | 41.5807% | 29.8409% |
| 전체 최대 film 두께/mm | 13.138852 | 5.242600 |
| 최대 Courant 셀의 두께/mm | 11.914823 | 5.167685 |
| 최대 C 셀의 실제 면적/mm² | 0.368809 | 0.372829 |
| 최소 metric stride/mm | 0.579878 | 0.586621 |
| 접선 가속도/m/s² | 9.125857 | 8.593537 |
| 최대 C 셀에 든 물/mm³ | 4.394298 | 1.926660 |
| 그 물량의 등가 구 직경/mm | **2.032187** | **1.543840** |

속도 보존율은 수치 모델의 `min(1,.8/C)`를 film 체적으로 가중한 진단이다.
물의 손실 비율, 실제 주행 속도 비율, FPS 손실 또는 전체 수송 시간의 단일
축척을 뜻하지 않는다. 이 진단에서 모델 속도 억제는 각각47.9173%/40.2779%다.

원장 재계산은 제공된 residual과 출력 반올림 범위 안에서 일치한다.
누적 residual/input은 각각1.13235e-6/1.29318e-6이다. **물 보존과 올바른
수송 시간은 서로 다른 gate**이며, 물이 보존되더라도 이 속도 억제는 해결해야 한다.
두 snapshot 사이에는 정차→주행 전환이 포함되어 있으므로 그 차이를 일정
137km/h 상태의 공급률로 해석하지 않는다.

### 셀/단위 이상 여부

static `cells.dds`에서 (464,208), (551,211)을 실제 조회했다. 두 곳 모두
coverage=1, supported=true, coating=1이다. runtime 면적과 DDS 면적의 비율은
float 반올림 안에서1이다. partial boundary의 작은 면적으로 나눈 사례가 아니다.
여기에 비정상 접선 힘이나 표시 gain이 물리식에 들어간 근거도 없다.

film 전체를 실제 지원 면적으로 나누면 평균 두께는 약17.34/20.35µm다.
**전체가 균일하게 두꺼운 것이 아니라, 국소 높은 재고에 물량이 집중**되어 있다.
다만 이번 reduction은 주변 셀 분포를 포함하지 않는다. 각 peak가 고립 방울인지,
연결된 리뷸릿인지 또는 넓은 고임의 일부인지는 이 로그만으로 확정하지 않는다.
셀 stride는 수치 해상도이며 물리적인 모든 유동의 횡방향 길이 척도와 같지는 않다.

## 3. 확인한 원인과 물리 해석

production `shaders/rainFilmFlow.hlsl`은 다음 준정상 식을 쓴다.

```text
h_m = film_mm3 / area_mm2 * .001
v = tangentAcceleration * rho*h_m²/(3*mu) + airShear * h_m/(2*mu)
C = L1(projectUV(v) * grid * dt)
```

현재 rho=998.2kg/m³, mu=.001002Pa·s에서 위 두 셀의 **체적력 항만** 계산해도
430.21m/s/76.21m/s가 된다. 이것은 실제 물의 관측 속도가 아니라 현 코드가
만드는 준정상 목표 속도다. 전단 항·world Jacobian·벡터 방향까지 포함한
게임 max C를 이 scalar만으로 재구성한 값은 아니다.

같은 포물선 속도 형상에서 평균 관성을 보존한다고 가정하면 응답 척도는
`tau=rho*h²/(3*mu)`로47.14초/8.87초다. dt=.016368/.013070초보다 각각
약2880/678배 크다. 즉 이 높이의 물을 프레임마다 즉시 준정상 속도로 보내는
가정은 맞지 않는다. 이 tau는 축약 모델의 응답 척도이며 정확한
Navier–Stokes 고유모드의 감쇠 시간으로 주장하지 않는다.

기존 P3는 source/trail 물을 셀에 축적하고, P4a에는 옆으로 퍼지는 압력·접촉선
평형이나 film→head 복귀가 없다. 높은 국소 수주가 그대로 `h²` mobility를
키운다. **단위가 틀렸다는 진단이 아니라 수막 표현과 운동 모델의 적용 범위 문제**다.

현재 저장 접촉각90°에서 같은 두 셀의 물량을 고립 spherical cap으로
재표현한다고 가정하면 높이1.280/0.973mm, footprint5.149/2.972mm²다.
셀 면적의13.96/7.97배에 해당한다. 이 예시는 공간 표현 차이를 설명하며,
각 peak가 실제로 하나의 고립 spherical cap이라는 증거는 아니다.
등가 직경은1.5–2mm 수준이므로 물리 직경·질량이나 display gain을 줄여
이 문제를 맞추지 않는다. 낙하 빗방울의6mm 안정성 논의를 표면 합류 물량의
강제 상한으로 쓰지도 않는다.

문헌 대조: 길이 척도와 낮은 Reynolds 조건을 사용하는 장파장/윤활 근사
범위는 [Oron, Davis & Bankoff (1997)](https://journals.aps.org/rmp/abstract/10.1103/RevModPhys.69.931)에,
곡면 film의 두께와 평균 접선 속도를 함께 두고 관성을 다루는 접근은
[Roberts & Li](https://arxiv.org/abs/chao-dyn/9906011)에 기술되어 있다.
이 문헌이 아래의 실시간 전환 휴리스틱을 물리적으로 검증했다는 뜻은 아니다.

## 4. P4b의 우선 처리: 국소 고임을 기존 P1 head로 보존 전환

물량이 작은 고립 고임은 이미 검증한 P1의 접촉 면적·고착·관성·외력·합류를
사용하는 편이 전 셀에 복잡한 유동 상태를 추가하는 것보다 비용을 제한하기 좋다.
단, **균일한 수막을 작은 방울로 쪼개는 전환은 허용하지 않는다.**

### 이번 GPU 원형의 명시적 규칙

1. 16×16 셀 region마다 가장 높은 full-coverage 셀 하나를 고른다.
2. 네 이웃의 최대 높이를 남겨 둘 background로 삼는다. unsupported/partial
   이웃 또는 경계는 이 원형의 전환 대상에서 제외한다.
3. 초과 물량 중 float32 셀이 실제 잃을 수 있는 체적을 계산한다.
4. 물리 min diameter(.25mm)를 통과하고, 초과 높이가 같은 물량의 cap 높이보다
   높으며 cap footprint가 셀보다 넓은 국소 peak만 후보로 둔다.
5. 균일 sheet와 연결된 평평한 ridge, 얇은 trail은 이 조건에서 전환하지 않는다.
6. region과 슬롯 사이의 회전하는 일대일 소유권을 둔다. 빈 슬롯이고 같은
   프레임의 rain attached birth가 없을 때만 수락한다. 슬롯이 차면 물은 field에 남는다.
7. field 차감과 head 증가가 같은 수락 record를 사용한다. flux도 **전환 후 잔량**을
   사용하여 전환한 물을 같은 프레임에 또 수송하지 않는다.

이것은 보수적인 subgrid 분류 후보이며 실제 접촉선 분리 판정이 아니다.
특히 이웃에 비슷한 높이의 여러 셀을 가진 고임은 넘기지 못하고, 거절된 최고점이
같은 region의 다른 후보를 가릴 수 있다. 전체 connected-component 탐색을
실시간으로 추가하지 않은 대가다. 넓은 수막/리뷸릿에 대해서는 별도 수송 개선이 필요하다.

### 실제 게임 통합에서 필요한 원자적 연결

원형만 game에 넣으면 안 된다. P2 이벤트와 P3 publication을 다음처럼 연결해야 한다.

- source 이벤트는 기존4행에서 P4b일 때5행으로 확장한다. 기존0행의 head 위치를
  고임 위치로 바꿔도 **원래 rain incident 위치는5행에 별도 보존**한다.
  `rainFilmDescriptor`가 rain film/micro를 새 고임 위치에 잘못 놓지 않게 한다.
- 내부 전환 체적도5행에 기록한다. P2 extra total의 현재 spare W에 누적하면
  추가 reduction canvas 없이 source/head 잔고와 전환 이력을 맞출 수 있다.
- P2 gross film reserve는 누계이므로 현재 film과 같지 않다. P2 식에는 내부
  복귀를 별도로 더하고, P3 전체 원장에는 외부 input/손실로 더하거나 빼지 않는다.
- flux와 field resolve가 동일한 수락 이벤트를 읽고 전환량을 먼저 차감한다.
- head state/meta, source 총계, field/optics, tick/epoch를 모두 기존 atomic publication에
  포함한다. 어느 shader든 pending이면 모든 read bank와 시계는 이전 상태를 유지한다.
- reset/토글/stale readback/최종 불완전 slot group도 검증한다. 후보/이벤트는
  speculative write이며 publish 전에는 live field나 head로 보이면 안 된다.
- field의 과거 운동량은 현재 저장되어 있지 않다. 초기 head 속도 결정은 별도
  closure가 필요하며, 준정상430m/s를 넘겨서는 안 된다. 원형이 **운동량 보존까지
  검증한 것은 아니다**. 실제 head 출현/광학/경계 합류도 별도 game gate다.

## 5. 비용 판단

| 대안 | 예상 비용과 판단 |
|---|---|
| 위 bounded 고임 전환을 P2 이벤트에 통합 | candidate1 pass,1024×1 RGBA32F=16KiB,4096슬롯 이벤트 추가1행=64KiB. **추가 payload 약80KiB**. 기존 flux/resolve에 이벤트 조회/소유권 계산 추가, 이벤트 출력25% 증가. 신규 CPU 방울 루프/steady readback/draw 없음. 저비용 후보이나 GPU ms 미측정. |
| 원형 그대로 별도 acceptance pass 유지 | candidate16KiB+acceptance64KiB,2 pass. 테스트 편의를 위한 독립 구조다. 실제 통합안은 acceptance를 P2 이벤트에 접어 넣는다. |
| 관성·압력 film solver | 속도/운동량 history와 대칭 flux/paired commit 필요. RG32F 속도2 bank만으로4MiB, 설계에 따라 kinematics RGBA32F4MiB 및 여러 pass 추가. 안정성/압력 stiffness와 pending rollback을 먼저 검증해야 한다. 전환 다음의 독립 gate로 둔다. |
| 무조건 substep 증대 | 현재 max C/.8은 약15912/2124지만 전체 격자에 이 수를 그대로 적용하는 것은 부적절하다.2–8 bounded step은 보통 C에는 도움을 줄 수 있어도 이번 극값과 잘못된 준정상 가정을 해결하지 않는다. |
| 두께/직경/display gain/CFL만 축소 | 표시와 물리 분리 또는 실제 수송 시간을 훼손하므로 해결안으로 쓰지 않는다. |

candidate pass는1024 region×256 후보 셀을 순회한다. 셀별 field/metric 각1회와
region당 네 이웃/마지막 후보 조회가 필요하다. 전 격자를 네 이웃씩 탐색하는
무제한 물방울별 검색과는 비용 구조가 다르지만, serial region loop나 원거리
cache 조회가 무료인 것은 아니다. 메모리 수치는 payload이며 driver allocation/
컴파일 비용을 포함하지 않는다. 실제 game FPS 개선이나 수송시간 정상화를
이 byte/pass 수치로 보증하지 않는다.

## 6. 검증 결과와 완료 조건

`tools/check_s85_pool_prototype.py`: FXC ps_5_0 **/Ges /WX**와 D3D11 WARP에서6개 gate 통과.

- 제공 peak 물량을 넣은 **합성** field의 paired 전환: residual0mm³;
- 빈 슬롯 없음/동일 프레임 rain birth 우선: field 차감0, 물 보존;
- uniform2mm sheet/연결 ridge/얇은 trail/미세 방울 전환 거부;
- unsupported/partial coverage 제외;
- 슬롯1/7/8/9/40의 region 소유권·불완전 마지막 group·회전 coverage;
- 원형 전환 후 **실제 production P4 donor/gather**에 연결: 이중 지출 없음,
  잔차1.49e-8mm³, 모든 재고 음수 없음, micro/기존 loss 채널 보존.

이는 사용자의 실제 field texture 복원이나 production의 pending/epoch/budget
handshake 테스트가 아니다. 게임 P4b 전달·설치·검증 완료로 기록하지 않는다.
기존 P4 수송시간 gate는 미통과로 유지한다.

**다음 구현 범위는 위 paired P2/P3 handoff다.** 완료 후 낮60%에서 제한 질량
비중과 head/field 연속성을 비교하고, 남는 넓은 수막에 대해서만 관성/압력
수송 비용을 평가한다. 현재 단계에서 사용자에게 같은 진단 로그를 추가 요청할
필요는 없다. tuning/diameter/display gain은 그대로 보존한다.
