# ============================================================
# 배포용 dist 폴더 생성 (Cloudflare Pages 직접 업로드용)
# ============================================================
#   powershell -File make_dist.ps1
#
# Unity 빌드는 WebGLBuild.cs의 DefaultOut에 따라 항상 v1.9\unity3d 로 나간다.
# dist는 그 사본이라 빌드할 때마다 낡는다 — 배포 직전에 반드시 이걸 한 번 돌릴 것.
#
# 웹에 올리면 안 되는 파일은 "복사 목록에 없어서" 제외된다. 제외 목록이 아니라
# 포함 목록 방식인 이유: 나중에 개발 파일이 늘어나도 자동으로 안 딸려간다.
#   · serve.js           로컬 테스트 서버
#   · supabase_setup.sql DB 스키마·RLS 정책이 그대로 노출된다
#   · README_3D모드.md   내부 문서
#   · make_dist.ps1      이 파일
# ============================================================
$ErrorActionPreference = 'Stop'

$src  = $PSScriptRoot
$dist = Join-Path (Split-Path $src -Parent) 'ShoichiSimulator_v2.0_dist'

# 사이트 루트에 들어갈 것만 나열한다. _headers 를 빠뜨리면 .unityweb 브로틀리를
# 브라우저 대신 JS가 풀어서 로딩이 눈에 띄게 느려진다 — 없어도 게임은 뜨므로 조용히 손해본다.
$include = @('index.html', '_headers', 'unity3d', 'sfx', 'sprite', 'icon', 'etc')

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Path $dist | Out-Null

foreach ($item in $include) {
    $p = Join-Path $src $item
    if (-not (Test-Path $p)) { throw "없는 항목: $p" }
    Copy-Item $p -Destination $dist -Recurse
}

$files = @(Get-ChildItem $dist -Recurse -File)
$mb    = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1MB, 1)
"dist  : $dist"
"파일  : $($files.Count)개 / ${mb}MB"

# Pages 한도: 파일 20,000개, 개당 25MiB. 넘으면 업로드가 통째로 거부된다.
$big = $files | Where-Object { $_.Length -gt 25MB }
if ($big) { $big | ForEach-Object { "⚠ 25MiB 초과: $($_.Name)" } }
if ($files.Count -gt 20000) { "⚠ 파일 20,000개 초과" }

# 빌드 산출물이 dist보다 최신이면 Unity 빌드를 다시 한 것이므로 위 복사로 이미 반영됐다.
# 반대로 dist가 최신인데 배포를 안 했다면 그건 사람이 챙길 몫이라 여기서 판단하지 않는다.
"`n다음: cd `"$dist`" ; npx wrangler pages deploy . --project-name=shoichi-simulator"
