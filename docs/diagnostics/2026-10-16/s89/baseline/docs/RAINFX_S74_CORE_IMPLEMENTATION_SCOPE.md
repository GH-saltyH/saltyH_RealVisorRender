# RainFX s74 — 구현 브랜치와 기본 물리 우선 범위

Date: 2026-10-14. Status: ACTIVE — 브랜치 준비 및 사용자 범위 조정 반영. 이번 단계는 문서 변경이다.

## 1. Git 기준

- 레거시 보존 기준: `0c092e0ea91729872c1230a5a351ad07baffa0a4`
  (`before phys/mass/whether refactoring stamp`).
- 보존한 기존 브랜치: `codex/visor-optics-e1-e7`.
- 파생한 구현 브랜치: **`codex/rainfx-physics-weather`**.
- 새 물리 모델의 P0–P4 구현과 검증은 이 브랜치에서 진행한다.
- 사용자가 커밋한 레거시 코드와 튜닝은 비교 기준으로 활용한다.

## 2. 사용자 결정

### Smear: 기본 모델 구현에서 제외, 이후 제거 여부 평가

Smear는 일반 차량 유리와 특수 바이저의 물 노이즈 표현 차이를 만들기
위해 추가한 보정 효과다. 기본 flow, sheet, 물리적 충돌이 충분한 물 흐름을
만들면 기능을 제거할 수 있다. 그러므로 새 기본 모델의 물리·수막·광학·UI가
Smear의 R/G 마스크나 기존 density/facing 계산에 의존해서는 안 된다.

첫 구현에서는 `RAIN_DYNAMIC_SMEAR_ENABLED`와 기존 shader mixing을 새
경로에 연결하지 않는다. 꺼진 효과의 계산·마스크 bake·scene-copy 요청도
실행하지 않도록 한다. 동명 legacy 설정은 비교 프로파일에만 남긴다.
기본 물리 모델의 상대풍/전단 계산은 독립 weather adapter에서 가져온다.

### Legacy local impact film: 새 모델에서 제외

`RAIN_DYNAMIC_IMPACT_SHEET_ENABLED`가 제어하는 추가 local impact film은
기본 구현에 이관하지 않는다. 기존 flux gate, 별도 film canvas, smear mix,
opacity/wave 보정과 UI도 새 모델에 연결하지 않는다.

**물리적 충돌은 유지한다.** 공중 방울의 입사각·속도·체적에 따른 퍼짐,
부착·반발·분열 및 국소 수막 공급을 구현한다. 이는 레거시 local impact
film을 다시 켜는 작업과 구분되는 기능이다. 실제 입사 물량과 동일한 체적
원장을 사용하는 기본 모델의 충돌 결과다.

## 3. 구현 순서와 판단 기준

1. P0: 입력·단위·표면 metric 검증. Legacy Smear에서 wind/facing을 빌리지 않는다.
2. P1: 물리 부피·질량·접촉선·외력·운동, 표시 크기 계수 분리.
3. P2: DSD·유입량·가상 충돌 초기화.
4. P3: 보존되는 trail/rivulet/sheet/micro 물, 건조와 기본 굴절 표현.
5. 기본 모델의 화면과 비용을 검증하고, 필요한 P4 transport 등을 진행한다.
6. 실제로 부족한 표현이 남는 경우에만 보정 효과의 필요성을 별도 평가한다.

기본 품질 평가:

- 정지/저속: 고착 방울, 병합, 중력 흐름과 고임이 자연스러운가.
- 고속/강우: 충돌과 전단으로 물이 넓어지고 빠져나가는가; 공급 없이 시트가 생기지 않는가.
- 스티커/코팅 경계: 흐름·고임·접촉선 이동이 물리 상태와 연속적인가.
- trail/head 시간 일치, 수막 두께와 굴절, micro의 크기 및 물량이 타당한가.
- Smear/local impact film을 배제한 상태에서 비용·메모리·frame spike가 기준을 충족하는가.

보정 효과를 복구한다면 기본 물 재고를 바꾸지 않는 광학 보정으로 설계하고,
추가 비용과 근거를 따로 기록한다. Smear의 red/green 표현 계약은 재도입할
경우의 역사 자료이며, 기본 물리 모델의 통과 조건은 아니다.

## 4. 이번 단계의 검증

브랜치의 HEAD는 보존 커밋과 동일하다. runtime·설정·shader를 수정하지
않았다. `docs/diagnostics/2026-10-14/s74/`에 수정 전 스냅샷과 SHA를
보존하고, `docs/tools/check_s74_scope.py`로 브랜치·부모 커밋·범위 문구와
runtime 불변을 확인했다. 물리 모델 구현/인게임 검증 완료를 의미하지 않는다.
