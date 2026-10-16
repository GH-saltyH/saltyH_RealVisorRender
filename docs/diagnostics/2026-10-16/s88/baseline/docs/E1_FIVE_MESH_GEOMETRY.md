# E1 현재 KN5의 5종 기하 교차 진단

## 구현 및 데이터

후속 구현: [BVH native colour 재투영](E1_BVH_NATIVE_COLOUR.md)을 연결했다. 아래 final 미연결 설명은 최초 기하 진단 빌드의 기록이다. 최신 빌드에서는 Source lit와 Primary 0/3/4/9/10으로 colour 연결을 검사한다.

활성 `visors/visor_lando_2025Champion_maxquality_diet_face.kn5`는 ModelWorks 원본으로 연결된 심볼릭 링크이다. 링크의 표시 길이 0을 원본 파일 크기로 해석하면 안 된다. 링크를 통해 실제 130,968,918바이트 원본을 읽어 BVH를 다시 생성했다. 원본 KN5와 링크는 변경하지 않았다.

| 메쉬 | 삼각형 | BVH 노드 | checker 진단 색 |
|---|---:|---:|---|
| BODY_FRAME | 65,289 | 16,383 | 빨강 |
| BODY_GLASSLINE | 43,672 | 16,383 | 녹색 |
| BODY_FABRIC | 65,415 | 16,383 | 파랑 |
| DRIVER_FACE | 28,906 | 8,191 | 노랑 |
| DRIVER_BALAKLAVA | 1,098 | 403 | 자홍 |

메쉬 이름 길이까지 확인하여 `_OVERLAY` / `_MIRROR` 이름을 잘못 추출하지 않는다. 각 메쉬 로컬 BVH를 실제 world transform의 역행렬로 추적한다. 방향을 로컬 공간에서 재정규화하지 않아 광선 거리 t는 월드 단위를 유지한다. 최근접 교차는 다섯 메쉬 전체에 걸쳐 결정한다. 현재 기하 검사는 양면 삼각형이며 원본 머티리얼의 alpha cutout/투명도는 포함하지 않는다.

`manifest.verify`의 모델 경로·5종 이름·SHA256을 확인한다. 런타임은 비동기 `io.checksumSHA256` 검증이 완료될 때까지 기하 출력을 막는다. 같은 경로의 모델을 수정하면 다시 bake 후 스크립트 reload 또는 `Recheck geometry model hash`가 필요하다. 생성 파일 전체와 manifest를 함께 반영해야 한다.

## 게임 확인 순서

1. 스크립트를 재로드하고 E1 primary를 ON한다.
2. `Primary actual geometry (five-mesh validation)` ON. 자동으로 Primary mode 6으로 전환된다. SHA256 확인 중이면 잠시 대기한다.
3. mode 6: 녹색 hit / 빨강 miss / 파랑 traversal budget 초과. `Actual geometry output before INT composite`와 바이저를 함께 확인한다.
4. Source mode 2 checker / Primary mode 3: 다섯 메쉬 색상과 각 메쉬 자체 UV의 체커를 확인한다. 소스 checker 선택은 진단 색 표시 조건일 뿐 캡처 이미지를 추적하지 않는다.
5. Primary mode 7: 최근접 hit 거리 / trace range를 회색으로 표시한다. mode 8: 헬멧 원점 상대 hit 위치를 월드 축 RGB로 표시한다. 각각 source 캡처 위치와 무관하다.
6. 메인 카메라 위치/FOV를 고정하고 source offset/FOV/pitch/height/slot을 바꾼다. 기하 진단 히트가 달라지지 않아야 한다. 메인 카메라를 움직이면 물리적으로 반사 광선이 바뀌므로 히트가 달라지는 것이 정상이다.
7. trace range 0.31 / 1.50m를 별도로 비교한다. 실제 거리 제한에 따른 miss를 캡처 누락과 구분한다.
8. OFF로 기존 captured-depth/lit 반사 경로에 복귀한다. 최종 색상과 조명은 이번 기하 진단에 연결하지 않았다. mode 0 final / 4 gate는 기하 모드에서 명시적으로 차단한다.

고정된 256픽셀 폭의 출력은 교차 검증용이다. 계단과 세부 해상도는 final 품질 평가 대상이 아니다. 현재 단계에서 sample budget은 캡처 깊이 추적용이며 BVH 추적량을 조절하지 않는다. BVH의 노드 방문 수와 삼각형 밀도가 별도 비용 요인이다.

## 검증

### 사용자 게임 검증 결과

- Mode 6: 다양한 메인 카메라 transform에서 납득 가능한 녹색 hit 영역을 확인했다.
- 우측 극단에서는 일부 빨강 miss가 남는다. 사용자 평가는 메쉬 형상/구도 특성상 수용 가능성이 있다는 것이다. 실제 형상 미스와 trace range 제한은 아직 구분하지 않았다. 첨부 설정의 range는 약 0.98m이다.
- 정면에서 빈틈 없이 채워진 체커와 5종 대상의 색상을 확인했다.
- Mode 7 거리 출력도 위 교차 반응과 일관되게 관찰됐다.
- Source offset 변경에도 기하 출력이 유지됨을 확인했다. Source FOV/pitch 각각의 독립성은 코드/입력 검사로 확인했으며 이번 사용자 피드백에서 별도 게임 확인됐다고 확대 해석하지 않는다.

판정: 현재 단계의 5종 기하 교차·렌더 경로와 source offset 독립성은 사용자 게임 검증을 통과했다. 다음 연결은 이 BVH hit 위치를 유지한 채 native colour를 복수 캡처에 재투영하는 것이다. 기하 miss, 기하 hit이나 유효 colour가 없는 경우, 검증된 colour hit를 각각 구분한다. 검증되지 않은 캡처의 다른 표면 색상으로 빈 부분을 채우지 않는다. 캡처에서 얻은 specular/Fresnel의 시점 의존성과 어느 소스에도 없는 색상은 여전히 제한 사항이다.

- 현재 원본 KN5 SHA256과 생성 데이터 모델 일치.
- 5종 총 140개 광선: 원본 삼각형 직접 검사와 packed BVH의 hit/miss 및 최근접 거리가 2µm 이내에서 일치. 축에 평행한 광선과 확실한 miss 포함. 최대 노드 방문 271.
- 실제 5종 HLSL FXC ps_5_0 /Ges /WX 컴파일 통과.
- LuaJIT 전체 구문, 기존 네이티브 가시성/캡처 보호 및 멀티뷰 회귀 통과.
- 실제 런타임 함수를 mock 검사: 비동기 hash 승인/불일치 차단, 5종 transform/texture 바인딩, source offset/FOV/slot/pitch와 기하 입력의 독립성, pending 실패와 final 차단.

실제 게임에서 교차 형상·합성·GPU 비용은 확인이 필요하다. 이번 결과가 맞으면 hit point를 복수 native colour 캡처에 재투영하고 depth/mesh ID 일치로 색상을 선택하는 다음 단계로 연결한다. 색상 관측 실패를 geometry miss와 구분하여 표시할 예정이다.
