import assert from 'node:assert/strict';
import {writeFile} from 'node:fs/promises';
import {Client} from '@modelcontextprotocol/sdk/client/index.js';
import {StdioClientTransport} from '@modelcontextprotocol/sdk/client/stdio.js';
import {fileURLToPath} from 'node:url';
const client=new Client({name:'FurniForge v0.2 integration test',version:'0.2.0'});
await client.connect(new StdioClientTransport({command:process.execPath,args:[fileURLToPath(new URL('../server/index.mjs',import.meta.url))],env:{...process.env},stderr:'pipe'}));
const id='ff_v2_custom_sofa_test';
const checks=[];
async function call(name,args={}) {return client.callTool({name:'furniforge_'+name,arguments:args});}
async function read(name,args={}) {const r=await call(name,args);assert.ok(!r.isError,r.content?.[0]?.text);return JSON.parse(r.content.find(c=>c.type==='text').text);}
async function rejects(name,args,pattern){const r=await call(name,args);assert.equal(r.isError,true);assert.match(r.content[0].text,pattern);checks.push(pattern.source);}
function box(id,size,position,color='#9d958a'){return {id,name:id.replaceAll('_',' '),kind:'box',size_mm:size,position_mm:position,color};}
function cushion(id,size,pos) {
 const vertices_mm=[[size[0]/2,size[1]/2,size[2]]],triangles=[];const n=32,m=16;
 const p=x=>Math.sign(x)*Math.pow(Math.abs(x),0.36);
 for(let i=1;i<m;i++){const lat=Math.PI*i/m;for(let j=0;j<n;j++){const lon=2*Math.PI*j/n;vertices_mm.push([size[0]*(1+p(Math.sin(lat))*p(Math.cos(lon)))/2,size[1]*(1+p(Math.sin(lat))*p(Math.sin(lon)))/2,size[2]*(1+p(Math.cos(lat)))/2]);}}
 const bottom=vertices_mm.length;vertices_mm.push([size[0]/2,size[1]/2,0]);
 for(let j=0;j<n;j++){triangles.push([0,1+j,1+(j+1)%n]);for(let i=0;i<m-2;i++){const a=1+i*n+j,b=1+i*n+(j+1)%n,c=a+n,d=b+n;triangles.push([a,c,b],[b,c,d]);}triangles.push([bottom,1+(m-2)*n+(j+1)%n,1+(m-2)*n+j]);}
 return {id,name:id.replaceAll('_',' '),kind:'mesh',vertices_mm,triangles,position_mm:pos,color:'#c1b9ac',smooth:true};
}
try {
 const status=await read('status');assert.equal(status.version,'0.2.0');checks.push('v0.2 live bridge');
 const req=await read('get_request');assert.equal(req.values.width_mm,1600);assert.equal(req.values.depth_mm,800);assert.equal(req.values.height_mm,850);
 await rejects('create_job',{job_id:'ff_v2_manual_conflict',plan:'Invalid test',assumptions:[{field:'width_mm',value:'1800',reason:'test'}]},/Do not re-estimate/);
 let job=await read('create_job',{job_id:id,plan:'Test fixture: build four dark legs, base, two arms, two rounded seat cushions and two rounded back cushions. Check exact 1600 x 800 x 850 mm bounds. This is a custom mesh demonstration, not a product reconstruction.',assumptions:[{field:'construction',value:'Illustrative fixture',reason:'No product reference is supplied for this integration test.'}]});
 assert.equal(job.revision,0,'Run this test only with no existing test job.');
 const repeat=await read('create_job',{job_id:id,plan:'Idempotent retry'});assert.equal(repeat.id,job.id);checks.push('idempotent job creation');
 const parts=[box('base',[1600,800,170],[0,0,140]),box('leg_fl',[60,60,140],[80,80,0],'#302d29'),box('leg_fr',[60,60,140],[1460,80,0],'#302d29'),box('leg_bl',[60,60,140],[80,660,0],'#302d29'),box('leg_br',[60,60,140],[1460,660,0],'#302d29'),cushion('arm_left',[150,800,300],[0,0,300]),cushion('arm_right',[150,800,300],[1450,0,300]),cushion('seat_left',[640,620,160],[155,10,310]),cushion('seat_right',[640,620,160],[805,10,310]),cushion('back_left',[640,170,520],[155,630,330]),cushion('back_right',[640,170,520],[805,630,330])];
 job=await read('apply_parts',{job_id:id,expected_revision:0,parts});assert.equal(job.revision,1);assert.equal(job.part_count,11);assert.equal(job.measurements.manual_dimensions_match,true);assert.deepEqual(job.measurements.non_solid_parts,[]);checks.push('11 editable solid parts, including 6 custom meshes; exact dimensions');
 await rejects('apply_parts',{job_id:id,expected_revision:0,parts:[parts[0]]},/Stale revision/);
 await rejects('apply_parts',{job_id:id,expected_revision:1,parts:[{id:'bad',name:'bad',kind:'mesh',vertices_mm:[[0,0,0],[1,1,1],[2,2,2]],triangles:[[0,1,2]]}]},/Degenerate triangle/);
 assert.equal((await read('get_job',{job_id:id})).revision,1);checks.push('invalid geometry preserves revision');
 await rejects('request_review',{job_id:id,expected_revision:1,review_notes:'No previews yet'},/Capture perspective/);
 for(const view of ['perspective','front','back']){const r=await call('capture_preview',{job_id:id,view});assert.ok(!r.isError,r.content[0]?.text);const img=r.content.find(c=>c.type==='image');assert.ok(img);await writeFile(new URL('../../FurniForge-v2-demo-'+view+'.png',import.meta.url),Buffer.from(img.data,'base64'));}
 checks.push('perspective, front and back captured');
 job=await read('get_job',{job_id:id});
 await writeFile(new URL('../../FurniForge-v2-test-report.json',import.meta.url),JSON.stringify({checks,job},null,2));
 console.log(JSON.stringify({ok:true,checks,revision:job.revision,measurements:job.measurements},null,2));
} finally {await client.close();}
