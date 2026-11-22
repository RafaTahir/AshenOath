import { readdirSync, statSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
const root = 'D:/Temp/AshenOath/hardening-browser';
const runs = readdirSync(root).filter(x => /^run-\d+-\d+$/.test(x))
  .sort((a,b) => statSync(join(root,b)).mtimeMs - statSync(join(root,a)).mtimeMs);
const profile = join(root, runs[0], 'chromium-profile');
const [port, socket] = readFileSync(join(profile,'DevToolsActivePort'),'utf8').trim().split(/\r?\n/);
if (!/^\d+$/.test(port) || !socket.startsWith('/devtools/browser/')) throw Error('Invalid owned endpoint');
const ws = new WebSocket(`ws://127.0.0.1:${port}${socket}`);
await new Promise((done, reject) => {
  const timeout = setTimeout(() => { ws.close(); reject(Error('Owned Browser.close timed out')); },10000);
  ws.onopen = () => ws.send(JSON.stringify({id:1,method:'Browser.close'}));
  ws.onclose = () => {clearTimeout(timeout); done();};
  ws.onerror = reject;
});
console.log(`Closed owned browser: ${profile}`);
