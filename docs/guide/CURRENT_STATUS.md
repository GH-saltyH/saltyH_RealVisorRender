# 현재 구현 상태와 문서 우선순위

## 2026-10-25 `Refactor/rainfx-core`: RainFX v2 M1

[RainFX v2 core](../RAINFX_V2_CORE.md)(GPU 셀-gather)가 이 브랜치의 기본 경로다. v2가 켜져 있으면
legacy `RAIN_ENABLED`와 P0 프리뷰는 실행되지 않는다(끄면 원래 값으로 복원). 오프라인 검사(Lua 구문, mock, NumPy 참조)만
통과했고 **셰이더 FXC 컴파일과 CSP 게임 실행은 미검증**이다. 게임 전에 `python docs/tools/check_rainfx2_shaders.py`를 실행한다.
루트의 옛 P0 사본 18개는 이 브랜치 시작 시점에 이미 없다. 아래 legacy 설명은 비교·복구용 보존 경로다.


## 2026-10-25 정리와 새 설계 방향

[새 CSP 구현안](../RAINFX_CSP_REDESIGN.md)은 기존 P0 모델의 연장이 아닌 별도 설계다.
아직 구현되지 않았다. 현재 앱/P0는 비교·복구용으로 보존하되, 기존 P0 fault 해결을
새 설계의 선행 조건으로 강제하지 않는다. 아래 P0 구현·결함 설명은 보존 경로의 상태다.

구형 진단 UI38개와 독립 앱13개, 불필요한 실험 스크립트·산출물은 정리됐다.
현재 남긴 실행 코드 목록은 `docs/development/runtime_dependencies.json`의73개다.
중복 루트 product/preview 사본은 보관본으로 이동했고 현재 P0는 `docs/runtime/s282/`를 사용한다.

기준:2026-10-25, `rain_product_pool.lua` 연결 이후. 앱 버전0.6.0과 단계 s282는
서로 다른 식별자다. s282 폴더 안에서도 구현이 계속 변했으므로 커밋을 함께 기록한다.

최신 실행 결함: P0 시작4.84초 후 serial156/reason64로 중단됐다.
[재고 확정 입력 수정](../RAINFX_JOINT156_COMMIT_FIX.md)은 로컬 재현·회귀를 통과했지만
실제 CSP에서의 해결은 미확인이다. 이는 보존 P0 경로의 미해결 항목이다.

## 실행 경로

| 경로 | 상태와 용도 |
| --- | --- |
| 일반 앱·기존 RainFX | `realvisor.lua`의 기존 렌더링. 연속 물리 프리뷰 OFF 또는 실패 시 사용하는 경로 |
| P0 연속 물리 프리뷰 | 메인 앱→`docs/runtime/s282/rain_product_host.lua`→동일 폴더 pipeline/runtime/executor |
| P1/P2/P3/P4 등 옛 토글 | 개별 단계 검증·기존 경로용. 현재 제품 프리뷰의 필수 토글 목록이 아님 |
| s126–s278 독립/내장 진단 | 활성 프로젝트/설치 앱에서 정리됨. 복구 ZIP 내 역사적 도구 |

루트의 중복 `rain_product_pipeline.lua`, `rain_product_runtime.lua` 등은 정리됐다.
**현재 보존 P0는 `docs/runtime/s282/`를 사용한다.**
반대로 `docs/prototypes`의 이전 번호 모듈 상당수는 여전히 실제 P0에서 가져온다.
낡은 번호만 보고 삭제하거나, 루트 복사본만 수정하면 안 된다.

## 현재 P0에 연결된 것

| 요소 | 연결·검증 범위 |
| --- | --- |
| 날씨·차량·바이저 입력 | 실제 캡처. 강수·공기·관성·물리 재질을 전달. 트랙 젖음/물량을 바이저 물 재고로 직접 복제하지 않음 |
| 방울 birth와 SI 운동 | 체적·질량·표면 접착·중력·관성·공기력. 고정32Hz 물리 |
| 트레일·필드 | 방울에서 전달된 물, micro 저장·합류·증발. 별도의 전체 film 이류는 비활성 |
| 표시 | 승인된 GPU 상태 스냅샷, 최근 트레일16개 이력,4096×1024 fine optics, 프레임별 head/field 보간 |
| 고임 반환 |16×16 셀 영역의 잉여 film→빈 슬롯의 물리 방울. 성공한 birth만 원래 물 차감. 기존 운동·출구 재사용 |
| micro | 미해상 수량 저장과 광학적 haze 입력. 기존 procedural micro pattern과 동일한 기능이 아님 |

현재 P0에는 Smear·legacy local impact-film overlay를 추가 덧댐으로 사용하지 않는다.
기존 메뉴에 항목이 남아 있는 것과 새 경로가 이를 사용하는 것은 다르다.

## 완료로 보면 안 되는 것

- 광범위한 올록볼록 수막과 약한 비의 일관성: 미해결. 새 고임 반환의 로컬 결과도
  넓은 수막 왜곡을 충분히 줄이지 못했다.
- 국소 흡수·방울 합체: 현재 제품 경로 미구현. 작은 고착 방울과 슬롯 점유가 다음 병목이다.
- film 자체의 연속 이동·완성된 sheet/flow/impact 장면: 미완성.
- 새 보간·고임 반환의 실제 CSP 품질,2048/4096 전체 앱 frame time·장기 안정성: 미검증.
- 재질 계수와 충돌 LUT: 일부 추정값이다. 물량 보존을 통과했다고 실측 재질이 되는 것은 아니다.

P0는 게임에서 오래 `running`한 사례가 있으나 과거 `fault/overloaded`도 있었다.
최신 파일 조합에 대한 무조건적 안정성 보증으로 해석하지 않는다.

## 검증 근거를 읽는 방법

1. **구문/strict shader compile:** 코드가 컴파일되는지.
2. **WARP:** 실제 HLSL 수치·채널·물량 등. 소프트웨어 D3D11이며 사용자 GPU FPS가 아님.
3. **mock 제품 회귀:** 실제 host/메뉴 연결을 사용하되 엔진·solver 호출을 대체한 검사.
4. **Python/연동 장면:** 명시된 입력·프록시 범위의 비교. 실제 리플레이와 픽셀 동일하지 않음.
5. **실제 CSP 게임 평가:** 실행·외관·성능 각각 따로 판정. 현재 전체 시각 품질은 불합격 상태.

현재 핵심 근거:

- [표시 보간](../RAINFX_FRAME_DISPLAY_INTERPOLATION.md)
- [고임 반환·남은 한계](../RAINFX_REGIONAL_POOL_RETURN.md)
- [게임 화면 리뷰](../RAINFX_FINE_TRAIL_GAME_REVIEW.md)
- [날씨 입력과 진단](../RAINFX_WEATHER_RESPONSE_AND_DIAGNOSTICS.md)
- [목표 장면](../RAINFX_TARGET_SCENES.md), [평가 정책](../RAINFX_GAME_ACCEPTANCE_POLICY.md)

충돌하는 설명은 현재 호출 코드·현재 커밋의 이 문서·해당 구현의 최신 평가를 우선한다.
`docs/README.md`와 s번호 보고서는 역사 색인으로 읽는다. `lib.lua.README.md`는
생성된 CSP API 참고 문서이며 앱 사용자 매뉴얼이나 로드할 Lua 모듈이 아니다.
