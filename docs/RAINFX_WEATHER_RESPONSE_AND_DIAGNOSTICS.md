# 현재 날씨 반응과 12343 누적 운동량 진단 분리

2026-10-25. 기존 P0 continuous physical RainFX의 deposit+drying 경로에 적용한다.
이번에는 날씨 효과나 독립 probe를 추가하지 않았다. 실제 캡처 입력을 표시하고,
과거 누적 진단을 현재 물리 상태의 승인과 분리했다.

## 날씨 값을 바꾸면 무엇이 바뀌어야 하는가

|값|현재 연결|화면에서 기대할 반응/제한|
|---|---|---|
|Rain Amount/intensity|액체 유입률과 DSD 추정|새 충돌·birth·공급 체적 변화.0이면 새 강우 공급은 멈추지만 이전 물은 남음|
|풍속·풍향|상대 입사와 SI 공기력, 주변 풍속에 따른 DSD 혼합|관련 운동/입사 변화가 있어야 함. 고속 차량 운동이 작은 바람 차이를 압도할 수 있음|
|Humidity|증발식 및 공기 밀도|높을수록 마름이 느림. 자동 결로/haze 생성이나 micro 수 증가에 직접 연결되지 않음|
|기온|증발식·공기 밀도|주로 느린 영향. 물의 mu/rho/gamma·접촉각은20°C 참조/설정값이며 모든 물성이 T에 반응하지 않음|
|Pressure|공기 밀도|공기력의 간접 영향. 색/수막 강도를 즉시 바꾸는 knob가 아님|
|Rain Wetness/Water|트랙 상태 관찰·기록|바이저 수막·스프레이 공급에 직접 연결하지 않음. 이 값만 바꿔 효과가 그대로인 것은 현재 구현상 예상되지만 목표의 스프레이 추정은 아직 없음|
|Weather type|액체/눈·진눈깨비·우박 상 전환|액체 공급 gate. 같은 액체 강수·풍속이면 이름별 별도 효과 preset이 아님|
|구름·노면 온도·대기 mist|현재 표면 물 모델의 직접 효과 아님|게임 배경과 다른 영역. 표면 haze로 복제하지 않음|

현재 DSD의 혼합은 intensity와 주변 풍속에 근거한다. humidity/wetness/water를 포함한
풍부한 입력이 모두 새로운 방울 크기/물보라를 결정하도록 완료된 모델은 아니다.
환경 변경을 읽기 위해 매번 reload할 필요는 없지만, 물리 재질/교정/모델 설정 변경은
기존 reset 규칙을 따른다. fault 뒤에는 물리 capture/output이 중단되므로 계속 날씨를
바꿔도 같은 물리 모델의 반응을 시험하는 상태가 아니다.

기존 물은 보존되며 현재 baseline은 film을 제자리에 둔다.12343 직전 물 재고는
약21735.6mm³, 면적은약40288.6mm²이다. 당시 건조율은약0.01324µm/s로 작다.
이 정도 누적 물을 습도/온도 변경만으로 몇 초 만에 없앨 수는 없다. 이것을 고속 주행의
빠른 clear path/배수가 완성된 상태로 보지 않는다. 광학 coverage/offset이 이미 강하면
새 공급 변화가 화면에 적게 보일 수도 있다. 실제 유입이 바뀌었는지 먼저 구분해야 한다.

## 실제 입력 표시

같은 product UI에 Captured frame, engine rain/liquid rain, RH,T,wind, 추정 공급
number density(/m³), evaporation(µm/s), track wet/water를 표시한다. 이것은 **마지막
CPU 캡처**이며 마지막 GPU 적용 시점의 실측이 아니다. 로컬 변경 시험에서 실제
capture→composer→GPU 제출 header까지 rain0/양수 및 evaporation0/양수가 전달됨을
확인했다. 실제 CSP weather UI의 변경을 엔진이 적용했는지, 어느 수치가 바뀌었는지는
사용 중의 새 readout으로 구분한다. 마지막 두 실패 입력만으로 전체 수분간 날씨 조작
이력이 모두 반영됐다고 증명할 수는 없다.

## 이번256은 현재 물 재고 불일치가 아니다

실제12343 기록과 native 재평가:

- 현재 canonical/source/ledger stock이 일치하고 이번 step 물/운동량 검사는 통과한다.
- 기존 cumulative X residual≈−0.068628, 다음 residual≈−0.068627이다.
- 반면 누적 **net** 항 절대합 기준은0.083949→0.068389로 축소돼, 거의 같은
  오래된 진단 차이가 새 기준을 약0.35% 초과했다.
- 기존 FP32 누적 원장은 재계산 이력이며, 현재 상태를 적분하는 물리 변수는 아니다.
  이것만으로 현재 방울/물 상태가 잘못됐다고 판정할 수 없다. 어느 과거 가산에서 누적
  오차가 생겼는지까지 확정한 것은 아니다.

## 제품 정책 변경 — 전역 tolerance 증가가 아니다

현재-stock 비교, 단일 구간 물/운동량 closure, 모든 물량/finite/상태/세대·자원·시간
검사는 유지한다. 과거/새 cumulative **물량** closure도 유지한다. 누적 운동량 XYZ
closure만 제품 진입 승인에서 분리해 기록한다. 그 차이를 자동으로 실제 stock에
보정하거나 물리 상태를 다시 쓰지 않는다.

source decision의 원래128/256 diagnostic mask와 실제 residual은 유지한다. 승인된
구간에서도 기존640byte readback에서 이 bit를 읽어 UI에 누적 notice 수와 최근 serial을
표시한다. 추가 GPU pass/texture/readback은0이다. 실패를 성공으로 소급 바꾸지 않으며,
원래12343 record/capsule을 보존했다. 일반적인 모든 오차를 경고로 낮추는 정책도 아니다.

기록된12343을 쓴 native 검증에서는 source와 최종 receipt가 통과하면서 mask256과
residual이 남는다. 반대로 단일 구간 운동량·재고 운동량·물량 오류, NaN, invalid status,
그리고 이전 실제3688 재고 불일치는 여전히 거부한다. 변경 실제 shader3종 strict compile.
실제 capture/binder 변화와 accepted notice 지속 실행은 engine/GPU mock으로 검증했다.
실제 CSP/장시간 품질은 미검증이다.119resources·74draws/구간은 그대로다.

앱 reload 후 같은 P0 entry에서 적용된다. 별도 조건별 로그 행렬이나 장시간 시험을
추가 요청하지 않는다. 이 수정은 자연스러운 날씨별 화면 조합을 완성했다는 뜻이 아니다.
연속 모션, coherent appearance, 경로별 micro 해소와 강한 유입의 표현은 남은 목표다.

증거: `diagnostics/2026-10-25/product_weather_diagnostics/`.
