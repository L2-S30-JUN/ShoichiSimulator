# v1.9 — Unity 3D 전용 (2D 본체 제거)

v1.8까지는 2D 캔버스 게임이 본편이고 3D가 부가 모드였다. v1.9에서 **2D 본체를 걷어내고
3D 시뮬레이터를 본편으로 승격**했다. 로비의 "게임 시작"이 곧 3D 진입이다.

원본 `ShoichiSimulator_v1.7/`는 **골든 트레이스 추출 기준이라 동결**한다.
Unity 이식의 정답지이므로 어떤 이유로도 수정하지 않는다.
2D 모드 UI·진입 코드가 필요하면 `ShoichiSimulator_v1.8/index.html`에 그대로 남아 있다.

## 실행

Unity WebGL은 `file://`에서 뜨지 않는다(wasm/fetch가 CORS로 차단). 반드시 로컬 서버로 연다.

```
cd E:\claude\ShoichiSimulator_v1.9
node serve.js
```
→ 브라우저에서 `http://localhost:8000` (포트를 바꾸려면 `node serve.js 8123`)

`python -m http.server 8000`도 되지만, `.wasm`을 `application/wasm`으로 내려줘야
스트리밍 컴파일이 되므로 MIME이 맞는 `serve.js`를 권한다.

v1.8과 달리 **`file://`로는 로비 말고 할 수 있는 게 없다.** 본편이 3D라 서버가 필수다.
그 경우 로비에서 안내 문구를 띄우고 iframe을 아예 로드하지 않는다.

## 구조

```
index.html     로비 + 3D 진입 + 설정/랭킹/업데이트 내역 (2D 게임 코드 없음)
serve.js       로컬 정적 서버 (wasm MIME 포함)
unity3d/       Unity WebGL 빌드 산출물 (Build/, index.html)
```

## index.html에 남은 것 / 빠진 것

**남긴 것** — 3D가 그대로 재사용하거나, 3D 모드가 붙으면 바로 쓸 것들:

| 요소 | 이유 |
|---|---|
| `#settings-modal` | 키 바인딩·음량·입력지연 — Unity에 `SendMessage`로 넘긴다 |
| `#chal-modal` + Supabase | 챌린지 결과창·기록 등록·TOP10. 3D 챌린지가 붙으면 `openChalResult(clearMs, {onRetry, onLobby})` 한 줄로 재사용 |
| `#lb-modal` | 로비 → "랭킹" |
| `#notice-modal` | F11 전체화면·마우스 제스처 안내 (3D 진입 시 1회) |
| `#credit-modal` · `UPDATE_LOG` | 크레딧 / 업데이트 내역 (Supabase `site_updates`, 실패 시 코드 내 fallback) |
| 로비 모드 버튼 4개 | `disabled` + "3D 제작 중" 배지 상태로 목록에 남겨둠 — 자리를 유지해야 나중에 레이아웃이 안 흔들린다 |

**뺀 것** — 2D 캔버스에 묶여 있어 3D 재설계가 필요한 것들:
게임 루프·렌더러·입력 처리 전부, 더미 처치 챌린지, V자 각 퀴즈, 연막무스 파훼,
쇼이치 클래식, 콤보 녹화/재생(`#combo-modal`, `COMBO_VER 13` 코덱).
이식 설계는 `ShoichiSimulator_Unity\Ref\MODE_PORT_SPEC.md` 참고.

되살리는 순서는 `index.html`의 `── [보류] 3D 재구현 대기 모드 ──` 주석 블록에 적어뒀다.

## 설계 메모

- **iframe 격리**: 같은 문서에 Unity 로더를 넣으면 전역이 오염되고, `unityInstance.Quit()`이
  비동기라 로비를 왕복할수록 wasm 힙이 쌓인다. iframe에 가두고 나갈 때 `src='about:blank'`로
  통째로 언로드한다.
- **Esc**: 브라우저가 iframe 안에서 Esc를 소비하므로, 부모의 "로비로" 버튼을 항상 띄워둔다.
  포커스가 부모에 있을 때는 Esc로도 나갈 수 있다.
- **포인터 잠금 충돌 없음**: `plockOn=false`(macOS Safari 이슈로 보류)라 부모가
  잠금을 걸지 않는다. Unity WebGL 쪽도 `CursorLockMode.Confined`를 껐다(브라우저 미지원).
- **1920×1080 고정 + CSS 축소(`fitUnity3D`)**: 3D 카메라는 "화면 세로 1px = 월드 1px"이라
  보이는 월드 범위가 뷰포트의 픽셀 높이에 그대로 비례한다. 창 픽셀을 그냥 쓰면 exe
  전체화면(1080px)보다 낮은 만큼 시야가 좁아져 확대돼 보인다. iframe을 1920×1080으로
  고정하고 부모에서 `transform: scale()`로 줄여 넣으면, 부모의 transform은 iframe 내부
  좌표계에 영향을 주지 않으므로 안쪽 Unity는 언제나 1080px로 인식한다. v1.7~v1.8의 2D 본체가
  1920×1280 디자인 캔버스를 CSS로 축소해 넣던 것과 같은 방식이다.
  **반드시 이 `index.html`을 거쳐서 열 것** — `unity3d/index.html`을 직접 열면 캔버스가
  창 높이를 그대로 써서 그만큼 확대돼 보인다(디스플레이 배율 125%면 864px = ×1.25).
  게임 좌상단에 `[!] 화면 NNNpx` 경고가 뜨면 이 상태다.
  레터박스를 iframe 안에서 처리하지 않는 이유: Emscripten의 마우스 좌표 계산이
  `(e.pageX - rect.left) × (canvas.width / clientWidth)`인데 `rect.left`만 transform이
  반영돼서 커서가 어긋난다. 부모-iframe 경계는 브라우저가 변환해주므로 문제가 없다.
- **`file://` 차단 안내**: 그 경우 로더가 CORS에 막혀 검은 화면만 남으므로,
  iframe을 아예 로드하지 않고 `#unity3d-load`에 안내 문구를 띄운다.

## WebGL 이식에서 실제로 터진 것들 (윈도우 빌드에선 안 보이던 문제)

Unity 쪽 수정은 전부 `ShoichiSimulator_Unity/`에 있다. 재이식할 때 같은 함정을 다시 밟지 않도록 기록.

1. **StreamingAssets 접근 불가** — WebGL은 파일시스템이 없고 StreamingAssets가 HTTP로 서빙된다.
   `File.Exists`/`ReadAllBytes`가 예외 없이 조용히 실패해 커서·아이콘이 통째로 사라졌다.
   → `Resources/ui/*.bytes`(TextAsset) + `LoadImage`로 전환. 임포트 설정에도 안 휘둘린다.
2. **한글이 전부 공백** — 내장 IMGUI 폰트에 한글 글리프가 없다. 윈도우는 OS 폰트로 조용히
   폴백해줘서 여태 안 보였고, WebGL엔 폴백할 OS 폰트가 없다.
   → 나눔고딕(OFL, `Resources/ui/`)을 싣고 `OnGUI` 첫 줄에서 `GUI.skin.font`로 지정.
3. **로드 직후 카메라 폭주** — 첫 마우스 입력 전 `Mouse.current.position`이 `(0,0)`,
   즉 화면 좌하단 모서리다. 엣지 팬이 첫 프레임부터 최대 속도로 발동해 맵 밖으로 날아간다.
   → 실제 마우스 이동(`delta != 0`)을 관측하기 전까지 엣지 팬을 잠근다.
4. **커서가 캔버스를 벗어나도 계속 스크롤** — 브라우저는 마지막 좌표를 유지한다. 가장자리에서
   창 밖으로 빠지면 카메라가 무한히 흘러간다. 윈도우 빌드는 `Confined`로 커서를 가둬서 없던 문제.
   → 템플릿의 canvas `mouseenter`/`mouseleave` → `SendMessage("ShoichiDebugView",
   "OnPointerOverCanvas", …)`로 정지.
5. **우클릭 컨텍스트 메뉴** — Unity 로더는 막아주지 않는다. 안 막으면 우클릭 이동이 아예 불가능.
   → 템플릿에서 `contextmenu` preventDefault (마우스4·5 히스토리 이동도 함께 차단).
6. **캔버스가 960×600 고정** — 기본/Minimal 템플릿의 한계. iframe을 못 채운다.
   → `Assets/WebGLTemplates/ShoichiEmbed` 커스텀 템플릿.

## 3D 쪽 미구현

Unity에는 아직 **일반 연습(더미 상대 연습)만** 있다. 챌린지·V자 각 퀴즈·연막무스 파훼·
쇼이치 클래식·콤보 녹화는 미구현이고, 맵 비주얼도 임시 지형이다.
로비의 랭킹 UI와 Supabase 통신은 HTML 쪽에 이미 살아 있으므로,
Unity가 클리어 타임만 `postMessage`로 올려주면 결과창·기록 등록은 바로 붙는다.

## 재빌드

```
"C:\Program Files\Unity\Hub\Editor\6000.0.32f1\Editor\Unity.exe" -batchmode -nographics ^
  -projectPath E:\claude\ShoichiSimulator_Unity\UnityProject ^
  -executeMethod Shoichi.EditorTools.WebGLBuild.Build ^
  -buildOut E:\claude\ShoichiSimulator_v1.9\unity3d -logFile webgl_build.log
```

에디터에서는 메뉴 `Shoichi > Build WebGL (hybrid)`.
빌드 설정은 `Assets/Editor/WebGLBuild.cs`에 코드로 고정돼 있다.

## 배포 (Cloudflare Pages 기준)

**파일 1개당 25 MiB 제한**이 있다(무료·유료 공통). 무압축 wasm은 38.1 MiB라 배포가 거부되므로
빌드는 **Brotli + Decompression Fallback**으로 고정해뒀다 — wasm 6.7 MiB, data 3.0 MiB로 떨어진다.

Fallback 덕분에 서버가 `Content-Encoding: br`을 못 줘도 Unity 로더가 JS로 풀어서 그대로 뜬다.
헤더를 줄 수 있는 환경이면 `_headers`에 아래를 넣어 네이티브 해제로 더 빠르게 만들 수 있다
(로더가 자동 감지하므로 빌드는 그대로 둬도 된다).

Fallback을 켜면 확장자가 `.br`이 아니라 **`.unityweb`** 인 점에 주의 — 파일명이 안 맞으면
규칙이 통째로 무시된다.

```
/unity3d/Build/*.wasm.unityweb
  Content-Encoding: br
  Content-Type: application/wasm
/unity3d/Build/*.data.unityweb
  Content-Encoding: br
/unity3d/Build/*.js.unityweb
  Content-Encoding: br
  Content-Type: text/javascript
```

`serve.js`도 같은 헤더를 주도록 해뒀으니, 로컬에서 확인한 로딩 동작이 배포 환경과 일치한다.

배포 총량 약 11MB, 파일 51개(한도 20,000). 첫 방문자당 ~11MB가 나가지만 템플릿에서
`dataCaching: true`(IndexedDB)를 켜뒀으므로 재방문 시 다시 받지 않는다.
나중에 파일 하나가 25 MiB를 넘게 되면 그 파일만 R2(무료 10GB, 이그레스 무료)로 빼면 된다.
