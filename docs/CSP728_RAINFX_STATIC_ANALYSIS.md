# CSP preview728 dwrite.dll: RainFX 정적 분석

2026-10-25. 사용자 제공 DLL을 수정하거나 실행하지 않고 PE·문자열·ZIP·DXBC를 읽었다.
이 보고서는 원본 C++/HLSL 복원이나 RainFX 전체 동역학 이해의 완료가 아니다.

## 확인된 파일과 자료

- 경로: `lights-patch-v0.3.0-preview728/dwrite.dll`
- 크기142684456bytes, AMD64 PE32+, preferred image base0x180000000.
- SHA256: `027fe86e3ddef06ddf05a900da2898b974914d08ee03bb5dd842e77939bf56a9`.
- Rain 관련 문자열150개, 해당 문자열 시작 RVA에 대한 RIP-relative LEA 참조178개를 수집했다.
  이 참조 스캔은 완전한 disassembly/call graph가 아니다.
- DLL 파일 offset0x2871000에 `shaders.zip` 로컬 ZIP 항목이 있다.
  ZIP payload는31944691bytes이며 암호화 flag가 없다.
- 내부 ZIP6739개 항목 중6724개가 DXBC로 시작한다. 이 숫자는 CSP 전체 셰이더
  자료이며, 모두 RainFX라는 뜻이 아니다.
- `__packed_data.ini`가 원래 셰이더 경로와 해시 형태 entry 이름을 정확히 연결한다.
  해시를 추측하거나 암호를 풀 필요가 없었다.
- `accRainWindscreen` 이름의72개 항목을 추출하고 Microsoft FXC `/dumpbin`으로
  전부 disassemble했다. `custom/`, `custom_l/` 두 변형군 및 VS/VSS/PS/CS를 포함한
  수치이며72개의 독립 simulation pass를 뜻하지 않는다. 변형군 선택 조건은 미확정이다.
- 다른 내장 자료에 `csp/rain_fx.ini`, `internal/configs/rain.zip`,
  `textures/rain_fx/drops.dds`, `hits.dds`, `puddles.dds`가 있다.

## 관련 CPU 코드 위치

`.pdata`의 runtime-function 범위와 직접 LEA 참조를 대조했다.

|대상|참조 instruction RVA|해당 runtime function RVA 범위|
|---|---|---|
|velocity 셰이더 이름|0xDE3F48,0xDE3F74|0xDE3680–0xDE41B6|
|move 셰이더 이름|0xDE3FA7,0xDE3FCB|0xDE3680–0xDE41B6|
|windscreen water1 리소스 이름|0xDE5192|0xDE4CC0–0xDE6587|

이것은 후속 CPU 분석의 시작점이다. 해당 함수의 전체 의미·호출 빈도·물리 계산을
복원한 것은 아니다. RVA는 DLL 로딩 후 ASLR 주소와 구분한다.
Export31개에 DWriteCreateFactory와 FSR 관련 명령들이 있으나 RainFX용 직접 export는
확인되지 않았다. 내장 구현 발견과 Lua에서 사용할 수 있는 공개 API 발견은 별개다.

## 이름과 실제 명령으로 확인한 처리

분석한 핵심 항목은 `rain_shaders/custom/` 아래의 이름이다.

### velocity

`accRainWindscreen_velocity_ps.fxo`는 t0의 주변21개 샘플을 읽는다. XY 성분을
각 샘플 A에 기반한 `0.1+0.9*A`로 가중해 평균하고 XY를 출력한다.
속도 맵을 주변 물 신호와 함께 평활화하는 구조로 읽을 수 있다. 실제 t0의 의미와
생성기·해상도·실행 빈도는 이 shader만으로 확정할 수 없다.

### move

`accRainWindscreen_move_ps.fxo`는 t1의 XY를 읽고 현재 UV에 그 값의0.002배를
더한 위치에서 t0를 샘플한다. XYZ를 전달하고 A를 다음과 같이 변형한다.

```text
v = Sample(t1, uv).xy
q = Sample(t0, uv + 0.002*v)
output.xyz = q.xyz
output.a = saturate(1.08*q.a - 0.04) - 0.005*(1-min(length(v),1))
```

이는 명령의 수학적 요약이며 원래 HLSL 소스가 아니다. A를 mm³ 물량이라고
확인한 것도 아니다. 마지막 값의 실제 clamp는 render-target format/후속 처리에
영향받는다. 샘플러의 경계/보간 설정과0.002의 시간 단위도 CPU 바인딩을 봐야 한다.
이 패스 자체는 보존형 이웃 flux 교환이 아니라 텍스처 좌표를 이동해 읽는 형태다.
이것만으로 CSP의 모든 물 효과가 비보존 방식이라고 일반화하지 않는다.

### waterFade, traces, finalize

- `waterFade`: t20의 공간 신호, CB12의 파라미터, t0/t2를 사용해 Z를 감쇠/제한한다.
  필드별 정확한 의미는 미확정이다.
- `blurTraces`: 중심과 고정된 주변7개 샘플의 X/Z를 평균하고 Y/W는 중심 값을 유지한다.
- `finalize`: 주변 높이 성격의 채널 차이를 LOD1.5에서 읽어 XY를 만들고,
  중심의 다른 두 채널을 Z/W로 전달한다. 명령상 gradient 형태가 확인된다.
  이것이 화면에서 어느 정상/굴절 단위가 되는지는 최종 소비자와 바인딩을 봐야 한다.
- 리소스 이름에는 water1/2, splashes, dirt, wipers, position, normals,
  occlusion, refraction mask, traces blurred, water blurred, final이 각각 존재한다.
  이름의1/2는 ping-pong 가능성을 시사하지만 실행 순서·전체 패스 수의 증거는 아니다.

`move` 등 핵심 bytecode에는 RDEF가 없어 원래 텍스처/변수 이름은 레지스터 t0/t1
형태로 남는다. DXBC instruction은 읽을 수 있어도 원래 주석·클래스 설계·변수명은
돌아오지 않는다. FXC 출력의 `Approximately0 instruction slots`는 제거된 통계 정보에
따른 표기이며, 이 셰이더가 비용0이라는 뜻이 아니다.

## 우리 프로젝트에서 활용할 범위

지금의 유익은 전체 바이너리 역공학을 새 선행 과제로 만드는 데 있지 않다.
다음 Python 비교에서 참고할 수 있는 구체적인 구조를 확보했다.

1. 물리 방울과 별개로 표현용 맵의 수송·감쇠·흔적 정리·법선 생성을 나누는 방법.
2. 속도/미세 흔적의 공간 필터를 어느 단계에서 수행하는지.
3. 물 재고를 SI 모델에 남기면서 저비용 광학 맵을 별도로 구성하는 대안 평가.

이 자료를 이유로 기존 SI 물리·표시 배율 분리 원칙을 폐기하거나, 색/coverage 값을
물의 양으로 취급하지 않는다. CSP의 실제 물리 모델, 갱신 Hz, texture 해상도와
2048/4096 비용은 아직 확인되지 않았다. 바이저와 자동차 앞유리의 재질 차이도 남는다.
런타임 DLL 패치·새 RainFX API·게임 코드 변경은 하지 않았다.

## 재현과 자료

- 도구: `docs/tools/inspect_csp_rain_binary.py`, `extract_csp_rain_shaders.py`.
- 결과: `docs/diagnostics/2026-10-25/csp728_rain_static/`.
- `inventory.json`: PE·문자열·코드 참조·내장 항목.
- `shader_inventory.json`: 전체 shader archive 인덱스·이름 단서.
- `rain_shader_manifest.json`: 정확한 원래 경로/entry/hash/assembly 대응.
- `rain_shaders/custom/accRainWindscreen_move_ps.asm.txt` 등: 실제 DXBC disassembly.

집중 분석 한 번과 두 자동 수집 도구 각1회로72개 항목의 읽기까지 완료했다.
현재 질문 범위의 확인을 위해 Ghidra 설치·대규모 CPU 디컴파일·게임 재실행은 하지 않았다.
