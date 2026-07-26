// 로컬 정적 서버 — Unity WebGL은 file://에서 못 뜨므로(wasm/fetch가 CORS에 막힘) 이걸로 연다.
//   node serve.js          → http://localhost:8000
//   node serve.js 8123     → 포트 지정
const http = require('http'), fs = require('fs'), path = require('path'), url = require('url');

const ROOT = __dirname;
const PORT = Number(process.argv[2]) || 8000;
const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.css': 'text/css', '.json': 'application/json', '.wasm': 'application/wasm',
  '.data': 'application/octet-stream', '.unityweb': 'application/octet-stream',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif',
  '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.webp': 'image/webp',
  '.mp3': 'audio/mpeg', '.ogg': 'audio/ogg', '.wav': 'audio/wav', '.sql': 'text/plain; charset=utf-8',
};

http.createServer((req, res) => {
  let p = decodeURIComponent(url.parse(req.url).pathname);
  if (p.endsWith('/')) p += 'index.html';
  // 루트 밖으로 나가는 경로(../) 차단
  const file = path.join(ROOT, path.normalize(p).replace(/^([/\\])+/, ''));
  if (!file.startsWith(ROOT)) { res.writeHead(403).end('forbidden'); return; }

  fs.stat(file, (err, st) => {
    if (err || !st.isFile()) { res.writeHead(404).end('not found'); return; }
    const h = {
      'Content-Type': MIME[path.extname(file).toLowerCase()] || 'application/octet-stream',
      'Content-Length': st.size,
      'Cache-Control': 'no-cache',
    };
    // Unity WebGL Brotli 산출물(.unityweb). 헤더를 주면 브라우저가 네이티브로 풀어
    // 로더의 JS 압축해제를 건너뛴다(= 배포처의 _headers와 같은 효과).
    // 헤더가 없어도 Decompression Fallback으로 동작은 하되 시작이 느려진다.
    if (file.endsWith('.unityweb')) {
      h['Content-Encoding'] = 'br';
      h['Content-Type'] = file.endsWith('.wasm.unityweb') ? 'application/wasm'
        : file.endsWith('.js.unityweb') ? 'text/javascript'
          : 'application/octet-stream';
    }
    res.writeHead(200, h);
    fs.createReadStream(file).pipe(res);
  });
}).listen(PORT, () => console.log(`http://localhost:${PORT}  (root: ${ROOT})`));
