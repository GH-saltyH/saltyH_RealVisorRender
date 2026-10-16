# RainFX s89 — film 진단 영상 검토와 양수 보존 overlap 원형

Date: 2026-10-16. Status: ACTIVE — 영상의 방향 반응은 현 단계에서 예상 가능. 물리적 수송 정확도는 미통과. **배경 차단 진단 view6 전달**, 보존 overlap 연산 원형의 GPU gate 통과. 수송 원형은 미설치.

## 1. 사용자 영상과 판정

원본: `E:/_db_Media/Rec_Encoded/OBS_SOURCES_QHD/film um check.mp4`.
2560×1440,30FPS,18.833333초다. SHA/ffprobe 기록은
`diagnostics/2026-10-16/s89/media.json`에 보존했다.
`.2,1.5,3,4.5,6,7.5,9,10.5,12,13.5,15,16.5,18초`의13개 시각 표본과
3/15초 원해상도 프레임을 확인했다. contact sheet는 `s89/frames/contact.png`다.
모든565개 프레임이나 개별 물방울의 연속 궤적을 검증한 것은 아니다.

### 관찰과 설명을 구분

- 넓은 자주색 진단 영역은 바이저 투영에 붙어 있고, 주행·조향 중 내부 색과
  일부 방울 위치가 변한다. 표본에는 visor 전체 진단 영역이 사라지는 모습은 없다.
- 녹색 점과 자주색 바탕이 함께 있어 **head/film/micro 합성 view5로 추정**한다.
  영상에 P3 UI 값이 없어 번호 자체를 확정하지 않는다. film-only view1과
  합성 view5는 서로 다른 색상 계약이다.
- 차체의 주황/노랑 무늬·트랙·하늘이 진단 뒤로 비친다. 이 색과 투영 변화까지
  실제 film 높이/물량 변화로 해석할 수 없다.
- 기존 P4는 매 step마다 P1의 object-to-world, 중력/차량 관성, 상대풍을 국소
  접선에 투영해 film 속도를 구한다. 따라서 조향/가감속/자세에 따라 **film의
  수송 방향과 분포가 바뀌는 현상 자체는 예상되는 동작**이다.
- 다만 이 모델은 준정상 속도이며 film 속도 이력을 저장하지 않는다. 힘 변화에
  즉시 반응할 수 있고, CFL 제한에서는 이동 시간이 늦어진다. 영상만으로
  속도·관성·배수·개별 head와의 연속성이 현실적으로 맞는다고 통과시키지 않는다.

**판정:** 현재 미완료 preview에서 설명 가능한 방향 반응이다. 물리 모델이
완성됐다는 의미의 정상 판정은 아니다. 넓게 칠해진 진단 면적을 전부 두꺼운
물막으로 세거나, 배경 색 이동을 전부 film 이동으로 세지 않는다.

## 2. 배경 차단 view6

기존 view5는 데이터가0이어도 `float4(link,.85)`를 반환한다. 이 pass의
premultiplied 합성에서는15% 배경이 남고, 빈 곳도 검은 alpha .85로 어둡게
보인다. 즉, **진단으로 칠해진 전체 mesh의 경계가 젖은 물의 경계는 아니다**.
뒤의 E2/E3와 tone 처리도 최종 표시를 바꿀 수 있다.

동일한 세 채널을 alpha1로 내는 **P3 view6**을 추가했다.

| 채널 | 의미 |
|---|---|
| R | film 높이: `log2(1 + h_um) / log2(1001)` |
| G | 현재 표시 head의 threshold support |
| B | micro 높이: R과 같은 로그 스케일 |

R/B는1000µm에서 포화한다. 예를 들어1/10/100µm는 약.100/.347/.668이다.
자주색은 film+micro 중첩이고 film 하나의 높이가 아니다. G의 크기는 display
gain에 영향을 받으며 실제 물리 직경을 이 색만으로 측정할 수 없다.

- view5 출력은 그대로 보존한다.
- view6는 **이 rain pass에서의 scene transmission**을 제거한다. 이후 visor
  optics까지 제거한 raw readback이나 재질·광학을 전부 끄는 기능은 아니다.
- 빈 데이터는 view6에서 검정이다. 검은 mesh 면적 자체를 물로 세지 않는다.
- exact depth 프로그램의 고체 물 판정은 그대로다. opaque 진단 alpha가
  새로운 물리 고체나 depth 차폐를 만들지 않는다. native occlusion은 유지한다.
- 추가 canvas/pass/texture/readback은0. 기존 uniform의 debug 선택만 사용한다.
  실제 물량·운동·날씨·직경·사용자 tuning은 바꾸지 않는다.

**사용:** 앱 reload → RainFX → Weather inputs and physical units(P0) →
P3 view **6**. 일반 출력은 P3 view/WF debug를0으로 둔다. 물리 재검증을 위한
정차/주행 로그 matrix를 추가 요청하지 않는다. 필요할 때 진단을 명확하게
보기 위한 도구다.

`tools/check_s89_isolated_view.py`는 실제 전체 production shader를 FXC
**/Ges /WX** + D3D11 WARP로 실행했다. view5 bit-equivalence, view6 동일 RGB,
scene 교체 불변, empty black, native 차폐, depth 불변과 정상 film-only/
head+film 출력의 s87 bit-equivalence를 통과했다. LuaJIT 전체 문법도 확인했다.
main/shader의 기존 게임 symlink로 전달되며, Lua 물리 모듈은 변경하지 않았다.

## 3. 다음 수송 구현 — source-local overlap

s88의 global prefix 차감은 서로 다른 face travel에서 음수 물량을 만들고,
큰 누적량 뒤의 작은 물량을 이동시키지 못했다. 이번 원형은 각 source 셀의
물량·운동량 packet과 **양의 폭을 가진 목적 구간**을 직접 겹쳐 합산한다.

```text
contribution(source, recipient) = source_packet
    * overlap(source_destination_interval, recipient_cell)
    / width(source_destination_interval)
```

경계 밖 비중은 같은 source 구간에서 runoff/유출 운동량으로 계량한다.
recipient에서는 Kahan 합을 사용한다. global 큰 prefix 두 개를 빼지 않으므로
멀리 떨어진 큰 고임이 얇은 흔적의 이동을 지워 버리지 않는다. 실제 같은
셀에 큰/작은 물이 겹쳐 최종 float32 표현의 ULP 아래가 되는 한계까지
해결했다는 뜻은 아니다.

### bounded hierarchy와 비용

source16셀을 leaf 하나로 묶고, leaf16개를 group 하나로 묶어 목적 구간의
min/max를 만든다. 수신 셀은 자기 영역과 겹치는 group/leaf만 방문한다.

1. leaf bounds + 같은 pass 두 번째 row bank에 source-local runoff packet;
2. group bounds;
3. recipient gather.

축당 **3패스**, 두 축6패스이며 **trajectory 생성 pass는 포함하지 않았다**.
production1024×256의 한 축용 raw payload 후보는:

- RG32 interval endpoints:2MiB;
- RGBA32 leaf bounds+loss:.5MiB;
- RGBA32 group bounds:.015625MiB;
- RGBA32 output packet:4MiB.

합계6.515625MiB이며, 기존 bank와 재사용할 수 있는지에 따라 순증은 달라진다.
두 축 사이 intermediate, P4 inertia predictor, 실제 film/micro/ledger와의 결합을
완료한 총 app Memory 수치가 아니다.

작업량은 무조건 저비용이 아니다.1024셀 균일60.25셀 이동에서는 수신 셀당
source interval 검사 평균16/최대32개, 실제 기여 평균1.882/최대2개였다.
난수 혼합 fixture에서는 검사 평균155.875/최대224개였다.1024개 source가
한 목적 셀에 고이면 그 셀은1024개를 검사한다. 모든 source 구간이 넓게
중첩되는 반례에서는 row의 모든 수신 셀이 source 전부를 검사한다.
즉 **최악에는 축별 row N²**가 남는다. 임의 candidate cap으로 일부 물을
생략하지 않았고, 이 연산량을 실제 게임 ms나 FPS로 환산하지 않는다.

### GPU gate

`tools/check_s89_overlap_transport.py` → `s89/overlap_checks.json`.
FXC ps_5_0 **/Ges /WX** + D3D11 WARP에서8개 검사 묶음을 통과했다.

- ±60.25셀 및 domain보다 긴±300셀 이동, 양수 물량/부호 있는 운동량/경계 원장.
- source travel이 급변해도 음수 재고 없음. `max(0)` 보정은 사용하지 않았다.
- 역방향 운동량·겹침·압축/확장과 double source-overlap 기준 비교.
- 30/60/144Hz의 **주어진 affine 특성선 끝점**에서 공간 연산 정확도 확인.
  변화하는 film PDE의 전체 timestep 수렴 검사가 아니다.
- 1e6mm³ 고임과 떨어진 .001mm³ 흔적의 이동: 최대 오차2.91e-11mm³.
  s88 반례에서36개 셀의 이동이 틀리던 문제를 이 구간에서 해소했다.
- 최종 partial leaf, 두 축, empty source, 명시적 runoff.
- 집중 고임과 광범위 중첩의 실제 후보 방문 수를 별도 노출.

## 4. 채택 범위와 남은 작업

이번에 통과한 것은 **유효한 목적 구간이 주어졌을 때의 양수 보존 remap 연산**이다.
목적 구간은 fixture의 입력이며, 아직 실제 수막의 힘/속도로부터 계산하지 않았다.
임의로 교차하는 구간도 양수 물량을 보존하지만 물리적으로 옳은 다중 흐름이라는
보장은 없다. 폭0/비정상 구간은 현재 test caller에서 먼저 거부한다.

다음 구현에는 다음을 묶어야 한다.

1. 곡면 UV와 실제 속도 이력에서 유효한 source 목적 구간 생성. 경로상의
   unsupported 셀/구멍을 뛰어넘어 물이 도착하지 않게 처리.
2. 서로 다른 속도·압축·정체점에서 전체 시간 수렴과 운동량/벽면 반력 검증.
   압력·접촉선 closure는 여전히 별도 미완료다.
3. 실사용 displacement/strain 범위에서 hierarchy의 최악 비용 통제. cap 초과
   source를 조용히 버리지 않고 fallback/계량 정책을 명시.
4. P4b debit, 새 source, head/field ledger와 pending/epoch를 함께 원자적 publish.
   invalid mapping이 일부 field만 갱신하지 않도록 GPU 수락 계약 구현.

따라서 **수송 원형을 아직 게임에 연결하지 않았다**. 게임의 추가 변경은
배경 차단 진단 view6/UI뿐이다. P1/P2/P3/P4 계수와 사용자 material 항목은
보존했고 Git commit/push는 하지 않았다.
