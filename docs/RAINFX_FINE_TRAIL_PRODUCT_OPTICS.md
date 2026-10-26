# 4096×1024 트레일 광학 후보를 P0 출력에 연결

2026-10-25. **이제 데이터 보존뿐 아니라 실제 P0의 반환 film 텍스처를 새 광학 소비
경로가 만든다.** 로컬 검증 완료, 실제 CSP 화면·성능 검증은 대기 중이다.
별도 probe가 아니라 기존 continuous physical RainFX preview를 사용한다.

## 구현과 공통 시점

`rain_product_visual.lua`가 기존 head/meta/coarse-film snapshot을 만든 뒤
`rain_trail_optics.lua`를 실행한다. 모든 패스가 같은 GPU selection 텍스처를 사용한다.
selection에는 최신 완성 joint receipt의 bank/serial/승인 상태/누적 물리 시간을 둔다.
최근16구간의 marker가 그 serial 이하이고 수명 범위 안인 경우만 표시한다.

방울과 트레일의 위치는 같은 승인 구간을 기준으로 한다. **32Hz 상태 사이의 연속
위치 보간은 아직 구현하지 않았다.** 이번 연결이 주행 시 움직임의 계단 현상을
모두 해결했다고 하지 않는다. 수막 물리 이동도 현재 baseline처럼 비활성이다.

## 수막을 중복하지 않는 복원

1.16개 coarse claim을4개씩 묶어 최근 표시 예산을 더한다. 기본 표시 이력.5초,
   마지막.15초 fade다. 이것은 증발 시간이 아니다.
2. 보존한 비닝과 summary로 공간 후보만 찾아, 선적분 커널에서4096×1024 표시
   가중치를 만든다.3구간씩 묶고 최대14개 텍스처 바인딩을 사용한다.
3. 기존1024×256 셀마다16개 표시 texel의 가중치를 합산한다. 최근 claim은 현재
   수막 이하로 제한하고, 같은 셀의 표시 물량 예산 안에서만 재분배한다.
4. 거친 수막 나머지와 세부 물량을 합쳐 최종 film 높이를 만든다. unresolved micro
   높이는 그대로 둔다. 형상 정보가 없는 셀은 균일한 coarse 표시로 돌아간다.

만료, 누락, 슬롯 덮어쓰기, 아직 승인되지 않은 구간 때문에 물을 새로 만들거나
증발시키지 않는다. 실제 생산 claim은 coverage 이후/field drying 이전 입력량이므로
현재 재고로 자르는 표시 근사를 사용한다. 실제 물 분자의 공급별 구성비 추적은 아니다.
기존60,000µm 표시 상한도 유지한다. 상한으로 잘린 표시 높이를 물리 원장에 되먹임하지 않는다.

gain은 현재 P0 display diameter gain×P2 display scale을 표시 폭에만 적용한다.
물리 반경·운동·질량에는 넣지 않는다. 비닝은 UI에서 허용한 최대 복합 gain4까지
지지 영역을 포함한다. 물리 support만 복사하면 큰 표시 gain에서 가장자리가 잘릴
수 있어, source export가 표시 기하로 별도 보수적인 bin/summary를 생성하도록 했다.

최종 유리 셰이더는 텍스처의 실제 크기를 읽어 미분 간격을 정한다. 예전1024×256
상수를 새4096×1024 결과에 적용하지 않는다. main Lua의 바인딩은 늘리지 않았다.

## 메모리와 실행 비용

품질을 위해 FP32 고해상도를 유지한다. 광학 workspace는 **102MiB/6개 canvas**다.

|추가 광학 자원|용량|
|---|---:|
|coarse claim ping-pong2장|2MiB|
|4096×1024 가중치 ping-pong2장|32MiB|
|셀별 정규화 RGBA32F|4MiB|
|4096×1024 최종 RGBA32F|64MiB|

기존 optical snapshot4개는 별도로 남는다. source 이력은 비닝 추가로4096방울에서
20.75024MiB이며, 매 물리 구간의 추가 source 작업은4→6드로우다. 첫 구간은21개
추가 드로우(모든 marker 초기화 포함)다. 자원 개수는 실행기199개+optical10개다.
이 수치는 할당 descriptor이며 드라이버의 정확한 VRAM 계측은 아니다.

재구성은12드로우다(claim4, sparse fine6, 정규화1, 합성1). 기존 snapshot4까지
합치면 한 재구성당16드로우다. **모든 렌더 프레임에서 반복하지 않는다.**
완전히 제출된 물리 구간 번호 또는 display gain이 바뀐 경우만 다시 만들고,
그 외에는 소유 중인 완성 텍스처를 재사용한다. shader 준비 중이거나 출력이 아직
완성되지 않은 경우에는 재사용 성공으로 취급하지 않는다.

이 CPU 번호는 dirty flag이며 bank/승인 선택을 대신하지 않는다. shader에서는
여전히 GPU receipt를 읽는다. 부분 제출 중인 다음 구간만으로 캐시를 깨지 않는다.
추가 readback이나 동기식 CPU 대기는 없다. 기존 private ordered 제출 가정은 유지한다.

대역폭·sparse 후보 수·커널 연산·제출 비용은 실제 GPU에서 확인해야 한다.102MiB가
수용 가능하다는 사실만으로 성능도 통과했다고 하지 않는다. 보수적 최대 gain bin은
현재 작은 gain보다 후보를 더 포함할 수 있다. 메모리 축소부터 하거나 전체 픽셀에서
모든 방울/모든 이력을 순회하는 방식으로 후퇴하지 않는다.

## 검증

- 제품 회귀13그룹 통과. 실제 host→pipeline→source export→fine consumer 반환
  연결, 고정 자원 수, 미완성/중단 처리, 동일 제출 상태 캐시와 새 상태 재구성을 확인했다.
  engine/solver GPU는 mock이며 실제 CSP 화면 확인은 아니다.
- 새 소비 셰이더4종을4×4 물리/16×16 표시 fixture에서 native WARP10 draws로 검증했다.
  거부·미래·만료 구간, 재고0/감소, micro 유지, 균일 fallback과 셀별 물량 보존을 포함한다.
  최대 셀 오차3.8e-9mm³다. 최종 게임 합격 기준을 이 오차로 새로 만들지 않는다.
- 실제 기록 선분의 동일 ROI에 생산 소비 셰이더를 적용했다(native13 draws).
  native 표시 bin이 CPU의 보수적 bin과 일치했고 부모 셀별 물량도 유지했다.
  source는 이전 rest-reset1초 경로와 CPU Gaussian coarse proxy다. 실제 CSP source
  raster, 새 birth/impact, 장기 누적 또는 게임 카메라를 재현한 것은 아니다.
- 원래 유리 렌더/래핑/깊이 셰이더3변형을 FXC `/Ges /WX`로 컴파일했다. 경고0.
  첫 소비 셰이더 검사에서는 signed integer `/4` 성능 경고가 오류 처리돼,
  음수가 아닌 좌표의 `>>2`로 수정했다. 경고를 끄지 않았다.

## 화면과 다음 판단

`native_path_comparison.png`는 같은 물량의 coarse/새 GPU 소비 경로 비교다.
선택 ROI와 작은 공급량 때문에 효과는 국소적이고 약하다. 부드럽지 않은 부분,
coarse 정규화 격자와32Hz 시간 계단이 남을 수 있다. 최종 C/B/A 장면 품질 통과가 아니다.
이미지의2×2 RGB supersampling은 offline 참조이며 게임 전체에 새로 추가하지 않았다.

앱 reload 후 같은 P0 프리뷰에서 `Fine trail optics:4096x1024;12 draws/new state`
안내와 optical rebuild/cache 횟수를 볼 수 있다. 새 앱이나 별도 메뉴는 없다.
실제 비 오는 세션에서 정차·주행의 연결/사라짐/심한 끊김·State·대략 FPS를 **한 번**
확인하도록 요청했다.2048/4096 반복 시험이나 별도 probe는 요청하지 않았다.

이 결과로 화면 품질과 실제 비용을 먼저 판정한다. 다음 구현 후보는 head/trail 공통
표시 위상의 보간이며, 비용 문제가 크면 계측된 재구성 병목부터 줄인다. 메모리 점유
만을 근거로 표시 해상도나 이력을 줄이지 않는다.

도구: `check_trail_optics.py`, `render_native_trail_optics.py`, `check_s282_product.py`.
결과: `docs/diagnostics/2026-10-25/fine_trail_optics/`.
