# CSP 윈드스크린 물방울 셰이딩 분석과 RainFX v2 적용 (rev28, 2026-10-27)

요청(사용자, rev27 리뷰): 줄무늬·측면 작은 방울 반투명이 계속 남음 → CSP가 물방울의 두께와 윤곽을 어떻게 처리했는지 분석해 모방.

## 1. 자료

- `dwrite.dll`(preview728) 내장 `shaders.zip` → `__packed_data.ini`로 `main_fx/ksWindscreenFX_new_ps.fxo`(=`z84eb9`) 추출,
  `docs/tools/dxbc_disasm.py`로 역어셈블 → `docs/diagnostics/2026-10-27/main_fx_ksWindscreenFX_new_ps.fxo.asm`.
- 리소스: `_txRainWater`(t1, finalize 결과 RGBA = 법선 xy 인코딩, 두께, 물 알파), `_txRainDetail`(t2), `_txRainWaterBlurred`(t5),
  `_txOcclusion`(t4, 표면 접선 인코딩), `txCube`(t13), `txPrevFrame`(t19).
- 앞 단계(소스 공개): 파티클 PS가 **평평한 윗면 + 부드러운 가장자리** 원판(fade = 반경 0.5–1 감소, 바깥 0.2 스커트)을 물 지도에 누적 →
  `accRainWindscreen_finalize`가 LOD 1.5(흐린) 높이의 차분 × 2.2로 법선 xy를 만든다.

## 2. 소비 셰이더가 하는 일(명령 요약, 원 소스 아님)

```text
n2  = water.xy * 2 - 1;  n2 = lerp(n2 * (0.1 + 0.9 a), detail.xy, saturate(2*blurred - 1));  nz = sqrt(1 - |n2|^2)
N   = 접선 프레임(occlusion 맵) × (n2, nz) → 월드 법선
// (1) 평평한 내부: 화면 굴절
uv  = screenUV + (-dot(side, N), dot(up, N)) * (0.25 + 0.25 * k);  c_scr = prevFrame.SampleBias(uv, blurred^2 * (...) - 2)
w_scr = saturate((nz - 0.3) * 10)                  // 법선이 표면과 거의 같은 곳만 화면 조회
// (2) 가파른 림: 화면을 읽지 않는다
Vb  = normalize(V + 0.5 (1 - nz) (-V - N));  c_env = cube(-Vb.x, Vb.y, Vb.z, mip 0) * 0.7
c   = lerp(c_env, c_scr, w_scr)
// (3) 반사
R   = normalize(lerp(reflect(V, N), N, 0.7));  c += cube(R, mip 2) * (1 - nz)^3 ...
```

핵심:
1. **두께 = 평평한 윗면 + 가장자리에서만 급해지는 법선**(흐린 높이의 기울기). 내부는 거의 배경을 그대로(작은 오프셋) 보인다.
2. **윤곽 = 가파른 가장자리를 화면이 아닌 큐브맵(월드 방향)으로 칠함** — 화면 조회가 없으니 축소 상 언더샘플링(줄무늬)이 원천적으로 없고,
   색이 월드 방향(위 = 하늘, 아래 = 지면)에서 오므로 위치·방향마다 다른 한쪽 음영이 자연스럽게 생긴다. 0.7배로 약간 어둡다.
3. 작은 방울도 가장자리 띠가 큐브맵 색이라 배경과 구분된다(반투명해지지 않음).

## 3. v2 적용(rev28, `visor.hlsl r2DropLens`)

- 방울 법선 N: 바이저 법선에서 중심 반대 방향으로 기울기, 기울기 = max(물리 캡 기울기, 1.27 × ρ_R²)(가장자리 nz ≈ 0.3 = CSP).
  ρ_R = 림 재매핑 반경: 림 띠 = 반경의 `rimBand`(0.25), 최소 `rimMinPx`(1.5 px), 최대 50 %.
- 내부: uv += −(N·side, N·up)·sgn × `cspRefract`(0.30) × lensK/0.35, 발자국 mip(상한 9).
- 림: CSP 식 그대로 큐브맵(`txReflectionCubemap`, mesh.fx 템플릿에 선언됨) × `rimEnvK`(0.7), mip `rimCubeMip`(1).
- 반사: CSP 식 그대로 × `reflK`(1).
- rev24–27의 물리 굴절 출구·Fresnel·전반사·환경 대체 경로는 제거(줄무늬·반투명의 원인 경로).
- UI: Drop rim width, Drop rim environment brightness, Drop reflection(+ 기존 lens strength = 내부 굴절 배율).

## 4. 검토(사용자 질문: 전체 필드 드롭 물방울을 모사한 것인가?, 2026-10-27)

- **대상은 윈드스크린 물방울이 맞다.** `_txRainWater`를 바인딩하는 셰이더는 `ksWindscreen_new_ps`, `ksWindscreenFX_new_ps`, `ksRearMirror_ps` 셋뿐이다
  (전체 아카이브 검색). 필드 물방울(월드 표면·나무·스키드마크 등)은 다른 텍스처 `txRainDrops`를 쓰며 rev28은 그것을 참조하지 않았다.
- **그런데 드롭처럼 보이는 이유:** rev28은 소비 셰이더의 *셰이딩 식*만 옮겼고 *법선의 출처*(물 지도)는 옮기지 않았다. CSP 방울의 모양은
  파티클이 그린 **평평한 윗면 + 부드러운 가장자리 원판**(`pfxWindscreen_ps`)을 물 지도에 누적하고, 이동(`move`: 속도장 이류 + 샤픈)으로 번지게 한 뒤,
  **LOD 1.5로 흐린 높이의 차분 × 2.2**(`finalize`)로 만든 법선이다. 즉 윤곽이 부드럽게 녹은 유막형 방울이다.
  rev28의 법선은 우리 셀 방울의 캡 기울기 + 가장자리 강제 기울기(1.27·ρ²)라서, 셰이딩은 CSP여도 모양은 또렷한 개별 원형 방울이 된다.
- **추가 발견:** CSP 자체의 헬멧 셰이더 `accNeckHelmet_ps`는 `_txRainWater`가 아니라 필드용 `txRainDrops`를 쓴다 — CSP가 헬멧 바이저 비를 필드 방울 지도로 그린다는 뜻이다.

## 5. rev29 — 윈드스크린 방식 완전 이식 (사용자 결정 2026-10-27: CSP 헬멧 방울은 카메라 효과라 제외)

파이프라인(바이저 UV 공간, `wmap.hlsl` + `visor.hlsl r2CspWater`):

|CSP 단계|CSP 원본|v2 이식|
|---|---|---|
|방울 스탬프|`pfxWindscreen_ps`: 평평한 윗면(반경 0.5까지 1) + 가장자리(0.5–1 선형) + 스커트(1–2, 0.2), 윤곽 노이즈 ×0.8–1.4, 미끄러지면 속도 방향으로 늘임|셀 상태 5×5 수집으로 같은 프로파일을 물 지도(1024×256 RGBA16F, 텍셀 ≈ 0.59 mm)에 max 누적. 가장자리 중앙 = 방울 반경, 늘임 = 0.6·이동/r|
|이동·샤픈|`move`: a = saturate(1.08a − 0.04) − 0.005(1−|v|)|모양(y)에 같은 샤픈. CSP는 0.5 위를 1로 몰아 와이퍼로만 지우므로, 세기(z)를 따로 지수 감쇠(`wmDecay` 0.5/s), 높이 w = y·z|
|법선|`finalize`: LOD 1.5 높이의 중심차분(1 텍셀) × 2.2|LOD `wmBlurMip` 1.75(0.59 mm 텍셀에서 CSP ≈ 2 mm 블러), 간격 `wmStepMM` 0.7 mm, × `wmNormalK` 2.2|
|셰이딩|`ksWindscreenFX_new_ps` 식|§3 그대로: nz > 0.3 화면 굴절(uv −(N·side, N·up)·k), 가파른 곳 큐브맵 ×0.7, 반사 (1−nz)³|
|덮임|(유리 셰이더 내부 혼합)|saturate(max(2·a, 3·|n2|))|

- 흔적: 움직인 방울이 남긴 물은 샤픈된 모양으로 남아 `wmDecay`로 사라진다(CSP의 물 흔적·번짐에 해당).
- 미이식: 속도장 이류(`velocity`/`move`의 uv 이동 — 매 프레임 셀에서 다시 찍으므로 생략), 디테일 법선(`_txRainDetail`, 두꺼운 물), 와이퍼.
- UI: `CSP windscreen water` 체크(끄면 rev28 셀 렌즈), 법선 블러, 법선 세기, 흔적 감쇠. Look lab에서도 동작(정적 세트, 감쇠 없음, 새 세트 시 지도 초기화).
- 비용: 물 지도 패스 262k 텍셀 × 25 셀 Load + mip 생성 1회/프레임, 바이저 픽셀당 텍스처 5회.
