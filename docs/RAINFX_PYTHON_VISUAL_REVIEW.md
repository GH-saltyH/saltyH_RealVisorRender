# Python으로 실제 물 재고를 시각화하며 개발

2026-10-25. 실행 도구: `docs/tools/render_rain_product.py`.
출력: `docs/diagnostics/2026-10-25/python_visual_review/`.

사용자는 이 이미지들이 게임에서 관측한 형태와 같다고 확인했다. 이 확인을 현재
문제의 시각 비교에 사용하는 근거로 남긴다. 카메라별/pixel별 동일성이나 새로운
동역학 후보까지 검증됐다는 뜻은 아니다. 앞으로 같은 초기 재고와 광학 조건을
유지하며 수정 전후를 비교한다. 첫 후속 결과는
[보존 수송 후보 평가](RAINFX_PYTHON_DRAINAGE_CANDIDATE.md)에 기록한다.

## 실제 값과 근사 구분

- 실제 CSP serial12343의 film/micro/state/meta DDS를 사용한다. 새 방울 위치나 물의 양을 임의 생성하지 않는다.
- 실제 KN5 du/dv, cell 면적, 물 부피로 두께와 접촉 반경을 구한다. 4096 기준6texels/mm와 현재 head 표시 배율을 사용한다. texel은 화면 pixel이 아니다.
- 실제 Lua `rain_birth_model.lua`를 Python에서 실행해 강수/바람에 따른 DSD를 그린다. 별도 Python 날씨 preset은 없다.
- 굴절은 기존 prism 식과 실제 표면 metric을 사용하지만, 배경은 합성 격자이고 투영은 평면 UV, 광학 거리는 고정100mm다. CSP 카메라·E2/E3·깊이·HDR·최종 합성까지 재현한 스크린샷이 아니다. 방울 렌즈와 micro blur도 근사다.
- 건조 비교는 새 공급·head·수막 이동 없이 같은 join/evap 식을 float64/1s 간격으로 계산한다. 기존 FP32/32Hz 전체 solver replay가 아니다. 5초의 총 셀 물량은 float64/32Hz 참조와 최대8.44e-15mm³ 차이였다. 이것은 CSP bit 동등성 검사가 아니다.
- 녹색 debug 표시는 실제 head 위치다. 저해상도 마커의 반올림 크기로 실제 직경을 측정하지 않는다.

## 이미지에서 얻은 개발 판단

1. 실제 field 재고는 film20481.52mm³, micro1217.45mm³다. field 물의94.39%가 film이다. 현재 film 두께의 셀 기준 중앙값444.60µm, p99는1875.33µm다.
2. `1-exp(-filmUM/2)`가95%를 넘는 셀은 유효 셀의96.66%, 물리 면적의96.38%다. 이것은 **광학 coverage 포화**이지 불투명 차폐율이 아니다. 새 공급 차이보다 이미 있는 넓은 수막이 화면을 지배하기 쉬운 상태다.
3. 비를 끈 건조 참조에서5분 뒤 field 물 감소는 기존 건조율에서 약0.72%, RH20% 가정에서 약5.65%다. 새 유입을 멈추는 것과 시야가 빠르게 회복되는 것은 다른 문제다. pinned film에 증발만 남긴 baseline으로 목표 B의 빠른 clear path를 완성할 수 없다.
4. 3x3 binomial 광학 높이 필터는 굴절 경계의 각진 부분을 줄이지만 넓은 패치와 누적 원인은 남긴다. UV 섬 경계를 넘는 평활화도 피해야 한다. **게임에 채택하지 않았다.** 필터만으로 수막 문제가 해결됐다고 하지 않는다.
5. 실제 Lua 공급은 intensity/ambient wind 변경에 반응한다. 이 그래프는 부착 후 방울 분포나 화면 점유율을 직접 예측하지 않는다. 현재 큰 재고에 가려지는 공급 반응과 입력 미연결 문제를 구분해야 한다.

## 비용과 다음 작업

이번 도구는 NumPy/Pillow와 기존 캐시 LuaJIT만 사용하며 SciPy 설치가 필요 없다. 마지막 이미지 생성은 로컬 약8.6초였다. 게임 FPS 예측치는 아니다. 게임 코드·물리 계수·GPU 패스/자원은 바꾸지 않았다.

다음 구현 판단에서는 **실제 물을 배출/재배분하는 최소 경로와 head/film 표시 계약**을 먼저 비교한다. Python 그림을 목표에 맞게 임의 변형한 뒤 물리 모델이 통과했다고 하지 않는다. 추가 정밀도 probe, 거대한 수송 연구, 새 물리 계수의 무제한 탐색은 재개하지 않는다. 후보 하나를 제한된 시간에 평가하고 장면 개선이 없으면 채택하지 않는다.

실행:

```powershell
& 'C:/Users/songak/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' docs/tools/render_rain_product.py
```

이미지:

- `optics_comparison.png`: 원본 격자 / 실제 물 debug / 현재 굴절 근사 / 필터 후보.
- `weather_drying.png`: 비 OFF 후0/60/300초, 같은 재고에서 건조율 비교.
- `weather_supply.png`: 실제 Lua DSD의 강수/바람 반응.
- `actual_uv_atlas.png`: 전체 UV 물 debug.
- `review.json`: 수치와 원본 파일 hash. `delivery.json`: 생성물 hash.

검증/반복: 이미지 생성5회 중4회 통과,1회 실패. 실패는 별도로 시간 평균된 air/evap 값을 순간식과 엄격히 동일시한 offline assertion이었다. 실제 입력의 시간 평균 의미를 반영했고 제품의 승인 기준은 바꾸지 않았다. 새 게임 실험 요청0회, 실제 CSP 실행0회.
