import { createHash } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import https from 'node:https';
import { artifactIdentity } from 'file:///D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns/tools/qa_002_artifact_identity.mjs';

const artifact = artifactIdentity('D:/Projects/AshenOath/web');
const files = [];
for (const expected of artifact.files) {
  const response = await new Promise((resolve,reject) => {
    const request=https.get(`https://ashenoath.vercel.app/${expected.path === 'index.html' ? '' : expected.path}?v=opening-presence-3751d51`, {headers:{'Accept-Encoding':'identity'}}, result => {
      const chunks=[];
      result.on('data',chunk=>chunks.push(chunk));
      result.on('error',reject);
      result.on('end',()=>resolve({status:result.statusCode,headers:result.headers,bytes:Buffer.concat(chunks)}));
    });
    request.setTimeout(60000,()=>request.destroy(new Error('Download timeout')));
    request.on('error',reject);
  });
  if (response.status !== 200) throw new Error(`${expected.path}: HTTP ${response.status}`);
  const digest = createHash('sha256').update(response.bytes).digest('hex');
  if (digest !== expected.sha256) throw new Error(`${expected.path}: hash mismatch ${digest}`);
  files.push({ ...expected, content_encoding: response.headers['content-encoding'] || 'identity', comparison: 'exact_bytes' });
  console.log(`PASS ${expected.path}`);
}
writeFileSync('D:/Temp/AshenOath/opening_presence/live_opening_hashes.json', JSON.stringify({ status:'pass', promotion_commit:'3751d51', verified_at:new Date().toISOString(), artifact_fingerprint:artifact.fingerprint, files }, null, 2));
