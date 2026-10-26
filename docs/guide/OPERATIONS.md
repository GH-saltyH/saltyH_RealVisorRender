# 운용과 문제 보고

[처음으로](../../README.md) · [현재 상태](CURRENT_STATUS.md)

## 일반 바이저

앱 이름은 `Real Visor Overlay`다. `Transform`에서 활성화·프로필·위치·회전·크기와
G-Force Motion을 조절하고, `KN5`에서 메시·재질·native glass 상태를 확인한다.
`RainFX`에는 기존 효과와 단계별 개발 메뉴가 함께 있다. 항목의 존재만으로 현재 P0가
그 효과를 소비한다고 판단하지 않는다.

카메라/차량마다 위치가 다르므로 먼저 바이저가 시야 앞에 있는지 확인한다. 너무 큰
near clip, 잘못된 위치·회전·스케일, 비활성 메시와 셰이더 오류를 구분한다.
저장된 프로필은 사용자 환경의 값이며 저장소 기본값이 보편적인 정답은 아니다.

## 현재 P0 연속 물리 RainFX

1. 비가 있는 게임 또는 리플레이 세션을 일시정지 해제 상태로 연다.
2. `RainFX → Weather inputs and physical units (P0)`로 이동한다.
3. `Enable continuous physical RainFX preview`를 켠다.
4. `Start continuous physical RainFX`를 누른다.
5. seed 캡처·자산 읽기·준비/워밍업을 거쳐 `running`을 확인한다.

현재 P0를 쓰기 위해 P1/P2/P3/P4 또는 s번호 probe들을 함께 켤 필요는 없다.
옛 독립 앱과 진단은 OFF로 둔다. 한 앱 로드에서 한 번 시작하는 구조이므로, 중지·실패 후
다시 시작하려면 메인 앱을 reload한다. 새 물 재고로 시작하며 이전 프리뷰 재고를 복원하지 않는다.

날씨·차량 입력은 실행 중 캡처된다. 물리 재질과 geometry 계약 일부는 시작 시 고정된다.
재질·물리 교정값·모델 스케일을 바꿨다면 reload 후 재시작해 비교한다. 표시 배율은
물리 질량에 반영되지 않아야 하며 일부 표시값은 실행 중 반영된다.

이 경로는32Hz 물리와 프레임별 표시 보간을 사용한다. 동일한 시간 비율로 방울과 수막을
전환하지만, 수막은 height crossfade이며 완전한 연속 유체나 부분 trail 재래스터가 아니다.
고임 반환과 실제 방울 출구는 연결됐지만 화면 전체 수막 품질은 아직 불합격이다.

## 상태와 지표

| 표시 | 해석 |
| --- | --- |
| `idle` | 시작 전. Enable만으로 시뮬레이션이 시작되지 않음 |
| `running` | 파이프라인이 계속 동작 중. 화면 품질·성능 합격을 뜻하지 않음 |
| `background_paused`, `resuming`, `repriming` | 백그라운드/복귀 처리. 일시적인 상태와 지속 정지를 구분 |
| `cancelled`/`stopped` | 중지 경로. 패널마다 명칭이 달라 옛 probe 결과와 혼동 주의 |
| `fault` | 입력·GPU 결과·자원·셰이더 등의 실패. 물리 출력 비활성화, 기존 렌더링 복귀 |
| `overloaded` | 처리/입력 수용 한계. 단순히 큐 용량만 늘려 고치지 않음 |
| `Submitted / audited / pending` | 제출·확인·대기 구간 수. 차이가 조금 있는 것은 비동기 구조상 가능 |
| `Advanced / debt` | 처리한 물리 시간과 보유 중 미처리 시간. 일회적인 작은 debt와 지속 증가를 구분 |
| `max pump` | 기록된 CPU pump 최고 시간. 전체 GPU 비용·평균 frame time과 다름 |
| `resources`, `Memory` | 전용 캔버스 수, 앱 메모리 등의 서로 다른 계측. VRAM과 Lua GC를 혼동하지 않음 |

시작 직후의 셰이더 준비는 가능하지만 오류/timeout 또는 계속 준비 중인 상태는 기록한다.
앱을 끄거나 중지해도 GPU 자원을 즉시 전부 해제한다고 보장하지 않는다. 확실한 세션 자원
초기화와 서로 다른 설치본 비교에는 게임 세션을 새로 시작한다.

## 날씨와 관찰 조건

강수량은 주로 입사 공급에 관여한다. 트랙 wetness/water, 습도, 바람, 상대풍, 차속,
바이저 방향, 이미 남아 있는 물과 재질은 서로 다른 입력이다. 비를 줄였다고 쌓인 물이
즉시 사라지는 것이 정상 기준은 아니다. 반대로 낮은 강수에서 새로 시작해도 과도한 넓은
수막이 생기면 미해결 결함으로 기록한다.

비교 시 다음을 함께 기록한다: 강수·wetness·water·습도·온도·바람, 차속, 바이저 방향,
앱/프리뷰 설정, dry start 여부와 누적 시간. 리플레이 날씨 오버라이드와 실제 캡처 입력이
같은지도 확인한다. 단지 날씨 프리셋 이름만으로 조건을 규정하지 않는다.

## 실패 자료 보존

앱 경로 기준:

```text
docs/diagnostics/runtime/rain_product_failure.txt
docs/diagnostics/runtime/rain_product_overload.txt
docs/diagnostics/runtime/frozen_current/request.txt
docs/diagnostics/runtime/frozen_current/*.zip
```

실패 시 일부 자료가 자동 저장된다. frozen DDS 저장은 비동기이며
`export requested`가 완전한 검증 완료를 뜻하지 않는다. request의 serial·시간과 DDS
원장 일치를 확인해야 한다. 새로운 실패가 같은 경로를 덮을 수 있으므로 reload 전에
보고서와 frozen 폴더를 한 묶음으로 다른 날짜/실험 폴더에 복사한다.

문제 보고에는 커밋/배포 묶음, CSP 버전, 재현 조건, 상태 전체 문구, First refused/reason/
context/head/slot/Source mask, 해당 보고서, 가능한 짧은 영상을 포함한다.
과거 환경에서는 기본 게임 로그가 누적 한도 이후 기록되지 않았다. 새 파일 보고서를 우선하고,
로그가 없다는 이유만으로 문제가 재현되지 않았다고 판단하지 않는다.

## 흔한 문제의 첫 분류

| 증상 | 우선 확인 |
| --- | --- |
| 앱이 목록에 없음 | 앱 폴더 중첩, manifest 위치, CSP Lua 앱 활성화, 목록/세션 갱신 |
| 모델·FX가 전혀 없음 | KN5 압축 해제·hash, Transform/near clip, 메시 가시성, Lua/셰이더 오류 |
| P0 모듈을 찾지 못함 | `docs/runtime/prototypes/probes` 누락, 루트 파일만 업데이트한 혼합 설치 |
| hash/geometry 불일치 | 모델·UV·mask·bake·manifest가 같은 자산 묶음인지 |
| UI 효과 설정이 반영되지 않음 | 기존 효과와 새 P0 경로 혼동, 시작 시 캡처 재질인지 |
| 수막이 넓게 덮음 | 현재 알려진 품질 결함. 무작정 shader/cache 재설치로 해결됐다고 하지 않음 |
| 낮은 FPS·주기적 멈춤 | 전경/배경 FPS 제한, 준비 중 컴파일, debt 추세, CPU pump와 GPU 비용 분리 |
| fault 후 기존 효과가 보임 | 기존 렌더링 복귀일 수 있음. 새 물리가 계속 동작한다고 오인하지 않음 |
