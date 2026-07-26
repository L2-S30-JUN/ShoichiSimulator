# v1.7 + Unity 3D 하이브리드 (임시)

원본 `ShoichiSimulator_v1.7/`는 **골든 트레이스 추출 기준이라 동결**한다.
2D 로직을 손봐야 할 일이 생기면 원본에서 하고, 이 폴더는 통합분으로만 유지한다.

## 실행

Unity WebGL은 `file://`에서 뜨지 않는다(wasm/fetch가 CORS로 차단). 반드시 로컬 서버로 연다.

```
cd E:\claude\ShoichiSimulator_v1.7_hybrid
node serve.js
```
→ 브라우저에서 `http://localhost:8000` (포트를 바꾸려면 `node serve.js 8123`)

`python -m http.server 8000`도 되지만, `.wasm`을 `application/wasm`으로 내려줘야
스트리밍 컴파일이 되므로 MIME이 맞는 `serve.js`를 권한다.

2D 모드(일반 연습·챌린지·V자 퀴즈·연막무스)는 `file://`로도 그대로 동작한다.
**3D 시뮬레이터 버튼만** 로컬 서버를 요구한다.

## 구조

```
index.html     2D 본체 + 3D 진입 코드 (원본 대비 6곳 패치)
serve.js       로컬 정적 서버 (wasm MIME 포함)
unity3d/       Unity WebGL 빌드 산출물 (Build/, index.html)
```

## index.html 패치 지점

원본과의 차이는 전부 `[임시]` 주석으로 표시했다. 되돌리려면 이 6곳만 지우면 된다.

| 위치 | 내용 |
|---|---|
| `<style>` 끝 | `#unity3d-wrap` 등 오버레이 CSS (z-index 290 — 로비 280 위, 모달 300 아래) |
| 로비 `.modes` | `#mode-unity3d-btn` 버튼 |
| `#lobby-screen` 다음 | `#unity3d-wrap` iframe 컨테이너 |
| `mode-smoke-btn` 핸들러 다음 | `enterUnity3D()` / `exitUnity3D()` + postMessage 수신 |
| `loop()` 첫 줄 | `if (unity3dActive) { lastTime = now; return; }` |
| `keydown` / `mousemove` / `mousedown` | `unity3dActive` 입력 가드 |

## 설계 메모

- **iframe 격리**: 같은 문서에 Unity 로더를 넣으면 전역이 오염되고, `unityInstance.Quit()`이
  비동기라 로비를 왕복할수록 wasm 힙이 쌓인다. iframe에 가두고 나갈 때 `src='about:blank'`로
  통째로 언로드한다.
- **2D 루프 정지**: 3D 중 `loop()`를 즉시 반환시킨다. 안 그러면 3D를 하는 동안 2D 쪽
  쿨다운·챌린지 타이머가 흘러버리고, 안 보이는 캔버스를 계속 그려 3D 프레임까지 갉아먹는다.
- **Esc**: 브라우저가 iframe 안에서 Esc를 소비하므로, 부모의 "로비로" 버튼을 항상 띄워둔다.
  포커스가 부모에 있을 때는 Esc로도 나갈 수 있다.
- **포인터 잠금 충돌 없음**: v1.7은 `plockOn=false`(macOS Safari 이슈로 보류)라 부모가
  잠금을 걸지 않는다. Unity WebGL 쪽도 `CursorLockMode.Confined`를 껐다(브라우저 미지원).

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

챌린지·Supabase 랭킹·맵 비주얼은 아직 Unity에 없다. 3D 모드는 일반 연습만 제공한다.

## 재빌드

```
"C:\Program Files\Unity\Hub\Editor\6000.0.32f1\Editor\Unity.exe" -batchmode -nographics ^
  -projectPath E:\claude\ShoichiSimulator_Unity\UnityProject ^
  -executeMethod Shoichi.EditorTools.WebGLBuild.Build ^
  -buildOut E:\claude\ShoichiSimulator_v1.7_hybrid\unity3d -logFile webgl_build.log
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
