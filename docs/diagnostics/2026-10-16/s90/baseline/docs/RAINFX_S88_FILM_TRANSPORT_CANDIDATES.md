# RainFX s88 — 유한 관성·장거리 수송 GPU 원형의 채택 조건 평가

Date: 2026-10-16. Status: ACTIVE — **오프라인 GPU 원형 평가 완료. 두 후보 모두 현재 형태로 게임에 채택하지 않음.** s87 runtime 유지. 수송 시간·head/film 운동/광학 통합은 미완료.

## 1. 이번 범위와 사용자 관찰

사용자는 view5에서 드문 녹색 head와 넓은 자주색 field가 별도로 보이는 이유를
확인한 뒤 계속 진행하도록 했다. 자주색은 red film + blue micro의 로그 높이
표시다. 고정 alpha .85의 진단이므로 색칠된 면적 자체가 두꺼운 sheet의 면적은
아니다. 원래 입사 event에서 직접 film/micro가 배분되므로 매 field 셀에 현재
head가 존재할 필요도 없다. 그러나 물 보존만으로 분포·운동·광학의 현실성이
검증되었다고 판단하지 않는다.

다음 통합에 앞서 s87의 미통과 항목인 **실제 시간에 맞는 수막 수송**을 다뤘다.
수송이 크게 늦어지는 상태에서 head를 그 속도에 맞추거나 광학만 섞으면 원인을
가릴 수 있다. 이번에는 유한 관성과 여러 셀을 넘는 보존 이류를 각각 고립했다.
P1/P2 물리 직경, 표시 gain, 날씨, 코팅, 사용자 material/tuning은 변경하지 않았다.

작업 전133개 runtime/shader/문서를 `diagnostics/2026-10-16/s88/baseline/`에
보존했다. 전 단계부터의 수정 내역과 source hash/mtime은 함께 기록했다.
이 원형은 모두 `docs/prototypes/s88/`에 있고 production shader factory에서
로드하지 않는다. 새 API나 steady CPU 루프/readback을 도입하지 않았다.

## 2. 후보 A: 물량과 함께 전달되는 유한 관성

### 모델 계약

수막의 평균 접선 속도 이력을 보관하고, 한 step의 높이·힘을 고정한 축소식:

```text
du/dt = a_t + 3 tau_air / (2 rho h) - 3 mu u / (rho h²)
t_relax = rho h² / (3 mu)
```

을 지수적으로 적분한다. step 끝 속도와 step 평균 속도를 따로 구한다.
후자가 donor travel을 결정하므로, 정지 출발을 곧바로 종단 속도로 이동시키지
않는다. 작은 dt/t_relax에서 phi 함수의 급수로 상쇄 오차를 피한다.

이는 **고정 높이의 relaxation closure**다. 곡면 film을 높이와 평균 속도로
함께 기술하는 접근은 [Roberts & Li](https://arxiv.org/abs/chao-dyn/9906011)에
나오지만, 이 원형이 그 논문의 완전한 모델이나 검증된 계수를 구현한 것은
아니다. 압력, 곡률 에너지, 접촉선, 회전 좌표계의 Coriolis/원심항을 포함하지
않는다. 물성은 현재 production과 같은 rho=998.2kg/m³, mu=.001002Pa·s다.

### 원장과 GPU 구성

- 예측 pass: old UV/s→world velocity, 현재 높이/외력으로 끝/평균 속도 계산.
- 기존 P4 donor의 **속도 입력만** 평균 속도로 교체. X/Y 순서의 quantized
  물량 차감과 production gather를 그대로 실행한다.
- momentum gather: 자기 잔량과 네 이웃 donor의 **동일한 확정 flux**에 끝
  속도를 곱해 전달. 새 rain/trail 및 joined micro는 이 후보에서 접선 운동량0으로
  들어오며, 추가 물은 평균 속도를 희석한다. 비례 증발은 평균 속도를 바꾸지 않는다.
- 곡면 수신 셀에서 donor world velocity를 접선으로 투영한다. 표면의 반력 때문에
  전역3D 운동량 보존을 주장하지 않는다. 평면·닫힌 지지에서의 이산 운동량을 검사했다.
- P4b pool return의 **물량**은 예측/잔량에서 먼저 차감하는 기존 함수를 재사용한다.
  pool→head 운동량 handoff는 이번 후보의 검증 범위가 아니다.

속도 RG32F 두 bank + 끝/평균 예측 RGBA32F 한 bank로 production 크기에서
raw **8MiB**, 기존 donor/gather 외 **2 steady pass**가 필요하다. 드라이버·정렬·
컴파일·MSAA 비용을 포함한 app Memory나 실제 게임 GPU ms는 아니다.

### 검사 결과와 채택 보류 이유

`tools/check_s88_film_inertia.py`: FXC ps_5_0 **/Ges /WX**, D3D11 WARP.

1. 1/20/500/1000/12000µm 고정 높이에서30/60/144Hz로1초 적분. 해석해의
   끝 속도와 적분 이동량에 상대 허용오차2e-5 이내. 변화하는 높이의 PDE
   timestep 수렴을 증명하는 시험은 아니다.
2. 정지 출발 유한 가속, 힘 반전 뒤 감속, 법선 힘 제외, 건조/zero-dt의 무이동.
3. skew/scale UV와 단일 object rotation에서 world 운동 불변.
4. 실제 production donor/gather의 물량 보존·pinned micro·수신 속도 전달.
5. 상반된 속도 packet의 평면 이산 운동량 보존.
6. 신규 정지 물량에 따른 속도 희석, 증발 후 평균 속도 유지.
7. 바람 전단과 기존 downward option의 방향 계약.
8. 1024×256 크기의 predictor 실행/유한값 검사.

사용자가 제공한 worst-cell 높이·minimum stride·접선 가속을 **정렬된 1축 합성
추정**에 대입하면 다음과 같다. 실제 texture 복원, 공기 전단 포함 수치 또는
실제 게임 C의 재측정이 아니다.

| 입력 지점 | 정차 | 137km/h |
|---|---:|---:|
| film 높이/µm |455.523|556.914|
| stride/µm |590.267|207.219|
| relaxation/초 |.06890|.10299|
| 정지 첫 step C |1.736|4.612|
| 충분히 가속된 고정 높이 C |16.375|58.444|
| .8 제한 시 국소 모델 속도 유지 |4.886%|1.369%|

**관성은 즉각적인 속도 변경을 개선하지만 warm transport의 CFL 지연은
해결하지 않는다.** 이 후보를 넣고 수송 정확도가 해결됐다고 선언하거나,
8MiB/2패스를 지불한 상태로 같은 실험을 사용자에게 반복 요청하지 않는다.

## 3. 후보 B: tiled prefix를 이용한 여러 셀 이류

단일 셀 donor stencil 대신, 체적/운동량의 구간 적분으로 먼 face까지 지나는
물량을 한 번에 구하는 원형이다. 각 축에16셀 local prefix→tile prefix→face
flux→gather의4패스를 둔다. source는0, domain 밖은 비어 있는 경계이고 경계
flux는 runoff/유출 운동량으로 계량한다.

```text
F(x) = piecewise-constant source packet의 누적 적분
q_face = F(face) - F(face - travel_face)
new_cell = old_cell + q_left - q_right
```

`tools/check_s88_long_transport.py`에서 production과 같은 FXC /WX + WARP로:

- 균일 이동0/1/17.25/60.25/-60.25/300/-300셀에서1D overlap 해와 비교.
  최대 channel 오차1.20e-7 미만, 체적+경계 유출은 정확히 닫힘. 운동량
  잔차는 최대4.14e-6 이내다.300셀은 domain 전체보다 길어 전량 유출한다.
- 두 축 순차 이동과 경계 유출의 원장을 확인했다.
- **서로 다른 face 속도에서 departure face 순서가 교차하면 음수 물량 발생**:
  .125mm³/cell의 합성 field에0→60셀 travel을 주면 최소 **-7.375mm³**.
  총량 원장은 여전히0 잔차다. 보존만 검사해서는 이 오류를 찾지 못한다.
- 큰 prefix(1e6mm³) 뒤 .001mm³의 얇은 packet을 놓으면, float32 누적합의
  상쇄 때문에 검사 구간96셀 중 **36셀의 이동이 틀림**. 합성 범위 시험이며
  게임에서 이런 큰 단일 고임을 관측했다는 뜻은 아니다. 이 경우에도 총량
  잔차는0이므로 공간적 정확도를 별도 검사해야 한다.

이 기본안은 두 축8 pass다. 기존 full-field donor1 pass를 대체하므로 순증은
그대로8이 아니며, descriptor/evaporation/atomic publish와 결합하기 전의
단독 비용이다. local prefix4MiB + 최대 tile prefix.25MiB + face flux약4.004MiB
+ axis intermediate4MiB로 약 **12.254MiB raw scratch**다. 일부 기존 flux/bank와
alias 가능한지에 따라 순증은 달라진다. 운동량 predictor와 함께 쓰는 총량을
단순히 두 표의 합으로 확정하지 않는다. 현 원형의 임시 출력은 RGBA32F다.

**이 후보도 현재 형태로는 채택하지 않는다.** max(0)로 음수를 자르면 물이
생성된다. travel을 다시 .8로 자르면 출발점의 지연 문제로 돌아간다. 얇은
흔적을 지운 채 큰 전체 물량의 상대 잔차만 통과시켜서도 안 된다.

## 4. 결정과 후속 구현 계약

이번 단계의 결론은 “관성 추가만으로 해결”과 “누적합 이류를 그대로 사용”을
배제한 것이다. **게임 동작은 s87을 유지한다.** 원형은 재현 가능한 검사와
비교 기준으로 보존하고, runtime toggle/UI/설치 대상에 추가하지 않는다.

다음 수송 원형은 아래 조건을 함께 통과해야 한다.

1. 상수 속도의 큰 이동은 정확히 통과시키고, 속도 차·정체점·반대 흐름에서는
   departure interval의 교차를 처리한다. 체적 clip/임의 속도 축소를 해법으로
   쓰지 않는다. 특성선의 공간적 추적이나 보존 overlap 재분배를 먼저 고립한다.
2. 큰 고임과 얇은 흔적이 공존할 때 공간적 이동을 검사한다. compensated/block
   primitive 등의 비용을 따로 산출한다. 전체 ledger 하나로 판단하지 않는다.
3. donor 물량과 운동량, 경계 유출, pool debit, 신규 source를 같은 commit에
   포함한다. 지원되지 않는 UV/곡면 이웃을 가로질러 transport하지 않는다.
4. 압력·곡률·접촉선의 closure는 별도 명시한다. 중력/전단의 relaxation만으로
   실제 수막 모양이 나온다고 주장하지 않는다. head 흡수의 다중 요청 배분과
   공통 광학 normal도 별도 미완료 항목이다.
5. positivity·균일 translation·비균일 흐름·thin packet·30/60/144Hz를 통과한
   후보에 한해 bounded pass/storage와 실제 게임 ms gate를 이어 간다.

여기서 정상 결과가 나오기 전에는 사용자에게 같은 날씨의 로그/FPS matrix를
다시 요청할 이유가 없다. 현재 s87 view5는 계속 사용할 수 있고, 앱 reload나
새로운 설정 변경은 필요하지 않다. Git commit/push는 하지 않았다.

## 5. 산출물

- `prototypes/s88/rainFilmInertia*.hlsl`, `rainFilmMomentum.hlsl` — 관성·paired 운동량.
- `prototypes/s88/filmPrefix*.hlsl` — local/tile prefix와 long-travel flux/gather.
- `tools/check_s88_film_inertia.py` → `s88/inertia_checks.json`.
- `tools/check_s88_long_transport.py` → `s88/long_transport_checks.json`.
- `tools/finalize_s88.py` → runtime/자산 불변, 문서와 원형 목록·SHA 감사.

실제 GPU 장치의 성능이나 인게임 외형을 이번 WARP 결과로 보증하지 않는다.
