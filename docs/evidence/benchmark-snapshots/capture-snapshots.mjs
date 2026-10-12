import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sourceSHA = execFileSync('git', ['rev-parse', 'HEAD'], {cwd:repo,encoding:'utf8'}).trim();
if (sourceSHA !== '91508623e577d6a1fb2f0f9e17c487edade048b6') throw new Error('Capture requires reviewed source SHA');
const output = path.join(repo, 'build/snapshot-evidence');
await mkdir(output, {recursive:true});
process.chdir(path.join(repo, 'benchmarks'));
const {harness, projection, canonical, digest} = await import('../benchmarks/test/harness.mjs');
const require = createRequire(path.join(repo,'benchmarks/package.json'));
const {chromium} = require('@playwright/test');
const h = await harness();
const auth = await h.token('snapshot-evidence-'+crypto.randomUUID(),{exp:'1h'});
const browser = await chromium.launch({headless:true});
const context = await browser.newContext({viewport:{width:1440,height:1080},recordVideo:{dir:output,size:{width:1440,height:1080}}});
const page = await context.newPage();
const steps = [];
const assert = (ok, message) => {if(!ok) throw new Error(message)};
async function show(action, result) {
  steps.push({action,...result}); console.log(JSON.stringify(steps.at(-1)));
  await page.setContent('<!doctype html><meta charset="utf-8"><style>body{background:#102126;color:#e0edef;font:18px system-ui;padding:32px}pre{white-space:pre-wrap;line-height:1.45}p{color:#aac5ca}</style><h1>Immutable benchmark snapshot workflow</h1><p>Synthetic signed account; actual local Worker, D1, private R2 and Queue. This is an API evidence viewer, not the native app.</p><p>Native-generated original prefix; injected synthetic feedback continuation. No live identity/provider calls. Token hidden.</p><pre></pre>');
  await page.locator('pre').evaluate((n,t)=>n.textContent=t,steps.map(s=>JSON.stringify(s,null,2)).join('\n\n'));
  await page.waitForTimeout(2000);
}
async function request(p,method='GET',body) {const r=await h.request(p,method,body,auth); const v=await r.json();assert(r.ok,JSON.stringify({status:r.status,value:v}));return {r,v}}
async function validated(sid,snapshot) {for(let i=0;i<100;i++){const {v}=await request(`/api/v1/sessions/${sid}/snapshots/${snapshot}/validation`);if(v.completeness)return v;await new Promise(r=>setTimeout(r,50))}throw new Error('Validation timed out')}
try {
  const raw = await readFile('test/fixtures/native-upload-v1.json','utf8'), chunk=JSON.parse(raw);
  const reg=await request('/api/v1/sessions','POST',{localID:chunk.sessionID,purpose:'sync',fixture:true,context:'fresh',consent:true});const sid=reg.v.id,p='/api/v1/sessions/'+sid;
  const added=await h.mf.dispatchFetch('http://localhost'+p+'/revisions/1/chunks',{method:'POST',headers:{authorization:'Bearer '+auth,'content-type':'application/json'},body:raw});assert(added.ok,'Native bytes rejected');
  const one=await request(p+'/revisions/1/finalize','POST',{sequenceEnd:chunk.sequenceEnd,hash:digest(raw)});await validated(sid,one.v.snapshotID);
  await request(p+'/contribution','POST',{consent:true,revision:1,snapshotID:one.v.snapshotID});
  await show('Finalize original native prefix; explicitly select contribution', {HTTP:one.r.status,cloudRevision:1,headSequence:one.v.sequenceEnd,headHash:one.v.hash,contributionRevision:1,fixture:'ineligible for benchmark credit'});
  const publicProjection=structuredClone(projection);publicProjection.includesUnknown=true;
  publicProjection.turns[0].replies[0].messages[1].revisions=[{text:'Synthetic earlier observed update. <script>window.compromised=true</script>',timingLabel:'Observed update: fixture timing; not model tokens'}];
  publicProjection.turns.push({id:'uncertain-turn',kind:'unknown',prompt:'Synthetic manually captured follow-up; scope uncertain.',scope:'unknown',targetedAgentIDs:['agent-a'],alignmentLabel:'Scope unknown; owner explicitly included this uncertain recording.',replies:[{agentID:'agent-a',outcome:'observedReply',messages:[{messageID:'uncertain-reply',text:'Scope uncertainty remains visible.',outcome:'observedReply',timingLabel:'Timing unavailable.'}]}]});
  publicProjection.limitations.push('Synthetic fixture: earlier revision and unknown-scope row explicitly selected for this demonstration.');
  const publication=await request('/api/v1/publications','POST',{consent:true,projection:publicProjection,previewHash:digest(canonical(publicProjection))});
  const before=await(await h.request(publication.v.path)).text();
  const opened=await request(p+'/revisions','POST',{consent:true,requestID:'continuation-'+crypto.randomUUID(),parentHash:one.v.hash,parentSequenceEnd:one.v.sequenceEnd});
  const compatibility=await request(p+'/validation');assert(compatibility.v.completeness,'Finalized result disappeared while continuation open');
  await show('Open private continuation; established validation remains available',{HTTP:opened.r.status,cloudRevision:opened.v.revision,compatibilityCompleteness:compatibility.v.completeness,oldPublication:'unchanged'});
  const reply=chunk.events.find(e=>e.kind==='replyObserved'), last=chunk.events.at(-1);
  const feedback={schemaVersion:1,id:crypto.randomUUID(),sequence:chunk.sequenceEnd+1,comparisonID:chunk.sessionID,segmentID:reply.segmentID,kind:'feedback',fixture:true,stamp:{...reply.stamp,wallMS:last.stamp.wallMS+1000,monotonicMS:Math.max(...chunk.events.map(e=>e.stamp.monotonicMS))+1000},previousHash:digest(canonical(last)),agent:reply.agent,messageID:reply.messageID,selection:'negative'};
  const continued={schemaVersion:1,id:crypto.randomUUID(),sessionID:chunk.sessionID,sequenceStart:feedback.sequence,sequenceEnd:feedback.sequence,previousHash:one.v.hash,events:[feedback],artifacts:[]};
  const appended=await h.mf.dispatchFetch('http://localhost'+p+'/revisions/2/chunks',{method:'POST',headers:{authorization:'Bearer '+auth,'content-type':'application/json'},body:canonical(continued)});assert(appended.ok,'Continuation rejected');
  const two=await request(p+'/revisions/2/finalize','POST',{sequenceEnd:feedback.sequence,hash:digest(canonical(continued))});await validated(sid,two.v.snapshotID);
  const history=(await request('/api/v1/contributions')).v.history[0];assert(history.snapshotID===one.v.snapshotID,'Private continuation moved contribution');
  const unchanged=before===await(await h.request(publication.v.path)).text();assert(unchanged,'Private continuation rewrote published page');
  await show('Finalize later private feedback; previous selections stay pinned',{HTTP:two.r.status,cloudRevision:2,headSequence:two.v.sequenceEnd,oldSnapshot:'immutable',contributionStillRevision:history.revision,oldPublicationBytesUnchanged:unchanged});
  await request(p+'/contribution','POST',{consent:true,revision:2,snapshotID:two.v.snapshotID});
  const updated=(await request('/api/v1/contributions')).v.history[0];assert(updated.snapshotID===two.v.snapshotID&&updated.revision===2,'Explicit selection failed');
  await show('Explicitly select newer snapshot, then withdraw',{contributionRevision:updated.revision,status:updated.status,lineageCredit:'one comparison; fixture credit zero'});await request(p+'/contribution','DELETE');
  await page.screenshot({path:path.join(output,'snapshot-workflow.png'),fullPage:true});
  const url=new URL(publication.v.path,await h.mf.ready).href;
  await page.goto(url);await page.locator('details').filter({hasText:'Synthetic earlier observed update'}).first().locator('summary').click();assert(await page.evaluate(()=>window.compromised)!==true,'Script executed');await page.screenshot({path:path.join(output,'reader-desktop.png'),fullPage:true});
  await page.waitForTimeout(2000); await page.evaluate(()=>window.scrollTo(0,document.body.scrollHeight)); await page.waitForTimeout(1500);
  const mobile=await browser.newContext({viewport:{width:390,height:844},recordVideo:{dir:output,size:{width:390,height:844}}});const mp=await mobile.newPage();await mp.goto(url);await mp.locator('details').filter({hasText:'Synthetic earlier observed update'}).first().locator('summary').click();await mp.screenshot({path:path.join(output,'reader-mobile.png'),fullPage:true});await mobile.close();
  await request('/api/v1/publications/'+publication.v.id,'DELETE');assert((await h.request(publication.v.path)).status===404,'Revocation failed');await request(p,'DELETE');
  await show('Revoke publication and delete private lineage',{publicPageHTTP:404,privateReadHTTP:(await h.request(p,'GET',undefined,auth)).status,cleanup:'tombstoned immediately; asynchronous content cleanup'});
  await page.screenshot({path:path.join(output,'snapshot-deleted.png'),fullPage:true});
  await writeFile(path.join(output,'metadata.json'),JSON.stringify({sourceSHA,fixture:true,steps,limits:['API viewer is not native UI','Original prefix is native-generated; continuation feedback and public unknown/revision rows are synthetic','No live identity/provider requests','Fixture contributions are ineligible'],publicationProjectionHash:publication.v.projectionHash},null,2));
} finally {await context.close();await browser.close();await h.close()}
