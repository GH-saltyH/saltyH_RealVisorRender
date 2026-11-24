# RainFX v2 물방울 외형: 현재 채택 상태와 로드맵

- **기준일:** 2026-11-25
- **이력:** `RAINFX_V2_TRAIL_REVIEW3.md` §1–59. 이 문서는 지금 동작하는 상태만 담는다.
- **저장 방식:**
  - `self.p`(대부분의 슬라이더)는 저장되지 않는다. 매 세션 init.lua DEFAULTS에서 시작한다.
  - ac.storage(STORED)에 남는 것: 노출, 접촉각(contactDeg), aperture, focus, D-A, scene mip, wobble, film / spray / scatter, debug 등이다.

## 1. 현재 파이프라인(바이저 렌즈)

| 층 | 형태 | 렌즈 |
|---|---|---|
| 셀 방울(머리) | 구형 캡. 테두리 각 θ_drop = contactDeg / f^1.5. 착탄 / 합체 후 물리 속도로 캡 복귀(R-steep). 히스테리시스는 접촉선 둘레 연속(S-fix2). Bond 윗면 평탄화 | 하나의 높이장 H(B3h, D-A 탭마다 L1). 굴절은 ∇H에서. 테두리는 CSP식: 반사 / TIR 몫 없음, 화면 밖 출사는 큐브맵(경로 제거, 2026-11-25) |
| 꼬리 | 머리 중심에서 폭 W, 높이 = 머리 캡의 ρ_n(0.75) 위치 높이(뒤 테두리 각)로 시작해(L2b, 머리 아래) Rr + 2.1W 동안 물길로 좁아지는 쓸기 목(L2) → 물길(B3c), 평평한 단면(B3e), visor에서 정확한 프로필(B3g). 단면 각은 원호 기하 sinθ = 2t/(1+t²), t = h/w | 같은 높이장 |
| 마이크로 조각 | 아틀라스 u(원판 위치) → 해석적 캡(U-micro). CoC 흐림(U-micro2). haze halo = 원판 창 + bilinear(2026-11-25) | 같은 r2DropLens 함수(셀 방울 아래 층) |
| 상 품질 | Stable lens(방울당 근축 발자국 mip), 카메라 상대 좌표(R-img4), 톤 압축 원본 k 0.01(R-img5). 방울 안 동공 defocus는 0(별도 defocus가 담당) | — |

## 2. 슬라이더 확정(2026-11-25, 사용자 결정)

| 구분 | 슬라이더 / 값 |
|---|---|
| 확정(현 값) | contactDeg 58(저장됨), shpMergeTau 0.015 s/mm, steep 켬, rimPhys 켬, bondFlatK 0.5, cubeK 0.7 / cubeMip 2, lensStable 켬 |
| 값 변경 | imgPupilMM 0.0(방울 안 상 흐림은 별도 defocus가 담당), sceneCompress 켬 + compressK 0.01 |
| 유지(조정 가능) | surfH / surfK, tailNeckRho 0.75(L2b), tailWidthK, tailFlat, headRound, tailK / tailMax / tailTau, coat* |
| 제거됨 | tirK, lensReflect(반사 / TIR 몫 + 반대편 면 출사), imgSmooth(B-spline), tailDrift, tailHazeWet, spreadVarK / R0 / R1 / WetK, wetFlatten, Lens part isolation + debug 12 |
| 재평가 대기 | housingM 0.05 m → H-mask(§59) 확인 후 다시 판단(0.02 권장) |

- steep / rimPhys / lensStable의 끔 경로는 코드에 남아 있다. 다음 정리(B5)에서 함께 지운다.
- 남은 검토 도구: debug 11(테두리 각).

## 3. 로드맵(우선순위)

0. **즉시:**
   - (확인) L2b 머리 복귀. 마이크로 halo 원형은 확인 대기
   - (확인) H-mask3 동작. housingM 재평가 대기(0.02 권장, §59)
1. **(완료) 하우징 H-mask3**(§59): 실제 하우징 메쉬를 단색으로 찍은 덮임 지도. 남은 일: housingM 기본값 결정
2. **렌즈 마무리**
   - (완료 L1) D-A 높이장
   - 마이크로를 같은 높이장으로 넣기(수요: 셀 방울과 맞닿는 곳의 층 경계. 지금은 작음)
   - 막 / 물길 상 규칙 정합
3. **흐름 B4:** 꼬리 끝 진주, 남은 물길의 노이즈 페이드 끊김(CSP waterFade), 꼬리 물 질량
4. **자취 끌림:** 머리가 젖은 자취로 조향된다(CSP move)
5. **B5:** 옛 trail 패스(trail.hlsl TG / TR1 / B2 / pearl) 은퇴. field R의 trail 물 공급을 꼬리 물 질량(B4)으로 대체한 뒤 제거. 렌즈 끔 경로(steep / rimPhys / lensStable / surfH 끔)도 이때 제거
6. **신규(2026-11-25):** CSP 앞유리가 다른 바이저 광학 모델(RainFX 제외)을 가린다. 원인 조사(그리기 순서 / 깊이 / 투명 정렬)
7. **신규:** INT 테두리 볼록 구간 광학
   - 레퍼런스처럼 영역 전체가 일정 각도로 장면을 틀어 굴절하고, 톤이 바뀌고, 조금 흐리다
   - 비굴절 영역과의 차이를 레퍼런스로 측정해 모델을 정한다(쐐기 프리즘 + 두께 흐림 후보)
8. **defocus(예약, 사용자 2026-11-25):** D-E 해석 컨볼루션 1탭(§58a)을 중심으로, 물 모델 / 다른 광학 / 인테리어 셰이더 마무리 후 통합 적용하며 재검토
9. 오염 C 모델, 약한 비 조정, cells 비용
10. **완료 / 유지:** 크기 분포(낮은 / 중간 / 많은 비 / 추종에서 레퍼런스에 근접, 사용자 2026-11-25)
