# RainFX s87 — P4b 게임 검토와 head/field 관계 진단

Date: 2026-10-16. Status: ACTIVE — 제공된 P4b 물 보존·고임 복귀·FPS 관찰 통과. 극단 두께 감소 확인. **수송 시간 정확도와 head/film 시각·물리 통합은 미완료.** 같은 좌표의 진단 view5 추가.

## 1. 기준과 보존한 사용자 변경

같은 조건의 replay를 쓴 사용자 s86 검토다. 정차/137km/h의 water/flow는 각각
동일 frame이다. 원본은 `diagnostics/2026-10-16/s87/p4b_actual.log`, 재계산은
`tools/review_s87_p4b_game.py`, 결과는 `s87/game_checks.json`이다.

작업 전132개 Lua/HLSL/문서를 s87 baseline에 보존했다. s86 전달 해시와 비교해
물리 모듈/관련 shader는 동일하며, 사용자가 `realvisor.lua`에 추가한
`KN5FABRIC / BODY_FABRIC_CULL / mtBODY_FABRIC` 재질 항목을 확인했다.
`s87/user_changes_since_s86.diff`에 별도로 기록하고 그대로 보존했다.
이번 runtime 변경은 기존 P3 디버그의 view5와 광학 함수의 초기화된 단일 반환 구조다.
물리·birth·film 재고·계수·날씨·표시 gain·재질 튜닝은 바꾸지 않는다.

## 2. 사용자 물 원장 및 제한 진단

| 지표 | 정차 frame45702 | 137km/h frame860628 |
|---|---:|---:|
| publishedSeconds | 112.154725 | 275.642188 |
| input/mm³ | 3185.837891 | 13049.377930 |
| film/mm³ | 227.257065 | 500.909058 |
| poolReturned 누계/mm³ | **9.385309** | **306.869751** |
| 전체 최대 film 두께/mm | **0.473947** | **0.874148** |
| 1mm 초과 셀의 film/mm³ | **0** | **0** |
| 제한 film 질량 비중 | **11.7477%** | **17.2450%** |
| film 체적 가중 모델 속도 보존율 | **91.8435%** | **86.2783%** |
| max Courant | 17.279570 | 60.205021 |
| residual/mm³ | 0.002228 | 0.022490 |
| 누적 residual/input | 6.99345e-7 | 1.72345e-6 |

두 누계의 차이는163.487463 published seconds, input9863.540039mm³,
residualDelta.020262mm³로 상대 오차2.05423e-6이다. 설계 기준1e-4 아래다.
**정차→주행 전환이 포함된 간격**이므로 일정137km/h 공급률로 부르지 않는다.
첫 정차 log의20.825471초 구간은 직전 snapshot이 제공되지 않아 별도로 재구성하지 않는다.
poolReturned는 내부 순환 누계이며 외부 입력으로 다시 더하거나 현재 field에서
한 번 더 빼지 않는다. `trailTransferred=93.633/394.179mm³`도 실제 head→field
전달이 있었음을 보여 주지만 개별 화면 방울의 trail을 식별하는 데이터는 아니다.

이전 s85 P4a는 제한 질량49.08%/44.83%, 속도 보존52.08%/59.72%, 최대
두께13.14/5.24mm였다. 새 관측은 훨씬 양호하다. 그러나 이전 snapshot은
publishedSeconds139.09/170.13, input6945.75/9551.62mm³로 **재고 누적 시간과
공급 이력이 다르다**. 같은 날씨라는 이유로 정밀한 일대일 개선율이나 인과 기여를
계산하지 않는다. 제공된 두 P4b 장면에서 극단 수주가 사라지고 내부 복귀가
실제로 작동한 결과는 수용한다.

최대 C 셀의 static 면적/coverage/coating도 조회했다.
정차(517,210): .377074mm²/1/1, 주행(662,202): .253065mm²/1/1이다.
주행 minimum stride는.207219mm로 더 촘촘하다. 남은 C를 partial 면적 오류로
돌릴 근거는 없다.

### 수송 시간 gate는 남아 있음

모델 속도의 체적 가중 억제는8.1565%/13.7217%다. 이것은 물 손실 비중이나
실제 차량 속도/FPS 손실을 뜻하지 않는다. 최대 C 셀의 속도 보존율은
`.8/C`로약4.63%/1.33%에 불과하다. positivity는 유지되지만 이 국소 수송은 느려진다.

현재 순간 최대 C를 그대로 dt에 나누는 명목 substep 수는22/76이다. 실제
동적 field의 필요한 적응 step 수나 전 격자 실행 계획은 아니다. 단순히2–8회
늘리면 문제가 전부 해결된다고 할 수 없다. h² 준정상 모델·압력/관성·해상도와
bounded 수송 방식의 비용을 함께 검토해야 한다.

## 3. FPS·Memory와 캡처 확인

사용자는 replay 첫 실행에서 P1..P4+선택적 P4b를 켜고 약40초에 캡처했다.
사용자 입력으로 정확한 시점은 조금 다를 수 있다.

| | P4b OFF | P4b ON |
|---|---:|---:|
| FPS | **67** | **67** |
| app Memory | 82.52MB | 85.99MB |

`images/s86_p4b/40sCapture_P4b_{Activated,Deactivated}.png` 두 원본을 확인했다.
두 캡처는 같은 구도/0:40 근처 replay 표시이며 ON에는 후보 canvas 항목도 보인다.
**이 조건과 측정 정밀도에서 추가 FPS 저하를 관측하지 않았다는 gate는 통과**다.
0ms의 추가 GPU 시간 또는100%/4096 최대 부하 전체 통과로 확장하지 않는다.

Memory 순간 차이는3.47MB다. GC 직후 최저값이나 시간 경과의 증가율이 아니므로
이를 누수로 판정하지 않는다. 반대로 장시간 memory gate를 통과한 자료도 아니다.
s86의80KiB는 raw GPU texture payload이고, app Memory 순간값과1:1로 비교할
수 없다. 기존 Lua40회 토글 fixture는 bank 소유권이 정상임을 보여 줄 뿐 실제
게임 장시간 heap 측정을 대신하지 않는다.

## 4. 영상과 “P2/P3가 따로 움직임”의 해석

원본 `videos/s86_P4b_GAME_REVIEW/s86_P4bTest_137kmh_LooksSeparate.mp4`는
2560×1440,30FPS,39.366667초다. `.5,3,6,...,30,36초`의12개 시각 표본과
18초 원해상도 visor crop을 확인했다. 메타데이터/표본은 `s87/media.json`,
`s87/frames/`에 있다. 모든 프레임의 jitter나 개별 방울의 인과적 연결을
연속 추적한 인증은 아니다. 표본에는 상·하단/스티커 경계에 커진 head들이
분포하고, 바이저 내부는 별도 광학으로 보인다. E2/E3/native 유리도 포함되므로
장면의 모든 왜곡을 P3 film으로 귀속하지 않는다.

### 표현 설정의 영향

사용자가 켠 **Water field debug2는 head의 기울기를 R/G 색으로 보여 주는
WF 진단**이다. P3 view2(micro µm)와 다른 설정이다.
이는 실제 P3 수막의 일반 굴절과 같은 방식으로 표현된 화면이 아니다.
P2 display scale2.000은 head의 표시 폭을 바꾸며 물리 volume/경로/P3 폭은
바꾸지 않는다. 다른 gain이 같다면 기본 P2 scale.40보다 head 표시 폭이5배다.
큰 색상 dome과 물리 높이의 field를 비교하면 폭/윤곽 차이가 커진다.
이 관찰을 잘못된 테스트라거나 모든 현상의 원인이라고 단정하지 않는다.

### 코드에서 확인한 연결과 미완료 부분

| 경로 | 현재 상태 |
|---|---|
| P2 입사 체적→head/film/micro | 같은 immutable event와 실제 입사 위치를 공유. 모든 film 위치에 head가 남는 것은 아님 |
| 움직인 head→trail | 같은 old/new state의 구간, head의 실제 체적 차감과 field deposit을 함께 게시 |
| field→새 head | P4b가 국소 고임 초과량을 빈 슬롯으로 이동. 새 head는 정지에서 시작 |
| field→P2 wet impact | 이전 실제 높이가 입사 분배에 반영됨 |
| 기존 head의 film 경로 추종/흡수 | **SI 운동에 P3 wet-path 마찰/유도/흡수는 아직 연결되지 않음**. legacy wet-path 코드는 SI 분기의 else에 있음 |
| head 운동 | 속도 이력·질량·cap drag·접촉각 hysteresis/고착·관성 |
| P4 film 운동 | 두께에 따른 h² 준정상/air skin shear, 독립 pinned/contact-line/압력/운동량 history 없음. 같은 힘 입력을 써도 같은 방향·속도를 보장하지 않음 |
| 광학 | head는 기존 WF slope/굴절, film은 물리 µm prism. 각각 scene을 샘플한 뒤 alpha 합성하며 아직 공통 수면 normal로 한 번 계산하는 구조가 아님 |

따라서 **좌표/체적/시간 연결은 있으나 완전히 같은 유체 운동·광학으로 통합된
상태는 아니다.** 사용자가 느낀 분리를 표시 설정 탓으로만 돌리거나 전체
구현의 시각 gate를 통과 처리하지 않는다. 기존 model/계수를 억지로 같게
만드는 수정으로 P1/P2 통과 결과를 훼손하지 않는다.

## 5. 동일 방울 GPU 검증

`tools/check_s87_head_field_link.py`는 실제 head metric/bounds/bin/summary/raster와
P3 descriptor/paired meta/deposition을 실행한다.30mm/s로0.5mm 움직인2mm
등가 방울의 **주어진 state 구간**을 사용한 분리 시험이며 게임 영상 복원이나
P1 힘 적분의 재검증은 아니다. shape lobe는 끄고 좌표를 고립했다.

- head centre UV=(.5,.5), trail centroid=(.49218749,.49999999), 즉 정확히
  old/new segment의 가운데다. 같은 step에서 head가 실제 잃은 .00308084488mm³가
  field에 들어갔고 오차는약−8.64e-11mm³다.
- display gain.4/1/2에서 head support 폭은약1.0/2.5/5.0mm로 변하지만,
  centre·descriptor·전달 물량은 동일하다.
- 빈 이전 field에서는 P4를 켜도 **fresh deposit은 그 step에서 먼저 이동하지 않는다**.
  donor는 이전 field만 읽고 새 trail은 이후 더해진다. 다음 step부터 이류한다.

결과는 `s87/head_field_link_checks.json`, 도식은 `s87/head_field_same_segment.png`다.
청록은 같은 물리 deposit, 주황은 표시 head의 합성 진단이며 실제 게임 화면이 아니다.
이 시험은 코드 수준의 공통 좌표와 지연 없는 생성 경로를 확인하며, 실제 화면에서
각 방울이 자연스럽게 연결됐다는 판정은 아니다.

## 6. 추가한 view5 — 한 좌표의 head/field 비교

앱 **reload** 후 RainFX → P0 → P3 view를5로 설정한다.

- **R/red:** 실제 film µm의 log 표시;
- **G/green:** 현재 표시 head의 WF threshold support;
- **B/blue:** 실제 unresolved micro µm의 log 표시;
- 노랑/흰색 계열: 채널이 같은 UV에서 겹침.

head 표시 scale은 여전히 green 폭만 바꾼다. view5 자체가 물리적 높이나
세대/slot identity의 대응을 뜻하지는 않는다. normal optics는 P3 view와
WF debug를 모두0으로 둔다.

기존 두 texture/동일 mesh shader를 사용하며 canvas/pass/steady readback/물리
계산을 추가하지 않았다. debug 경로에 head sample이 추가되고 일반 optics는
동일하다. FXC X4000을 피하도록 `rainPhysicalFilm`을 초기화된 single exit로 정리했다.
`tools/check_s87_link_view.py`가 full shader /Ges /WX, R/G/B 위치, native occlusion,
기존 정상 출력의 s86 bit-equivalence와 empty/depth/굴절 회귀를 확인한다.
root Lua와 물리 모듈의 전체 문법도 확인했다.

main Lua/shaders는 게임 폴더의 기존 symlink로 연결된다. 물리 Lua 모듈은 변경이
없으므로 새로 복사할 필요가 없다. 앱 reload 때 새 UI/shader를 읽는다.

## 7. 판정과 다음 범위

- 제공된 물 보존·복귀 활성화·극단 수주 억제 관찰·추가 FPS 관찰은 수용한다.
- head/film의 시각적 연결, 정확한 film 수송 시간,100%/최대 부하, 장시간 memory는
  별도 open gate다. 단일67FPS/두 Memory 순간값으로 모두 완료하지 않는다.
- 다음 통합 검토는 film의 유한 관성/압력·접촉선, 기존 head의 지역 wet-state
  피드백과 보존적 흡수, 그리고 공통 광학 normal이다. 각각 비용과 원장을 확인한다.
  단순 속도 맞춤/물리 직경 변경/무제한 substep/연속 sheet의 무조건 head화는 피한다.

현재 숫자 평가를 위해 사용자에게 같은 정차/주행 로그나 FPS matrix를 재요청하지
않는다. view5는 남아 있는 시각적 대응을 직접 볼 수 있게 하는 도구다.
