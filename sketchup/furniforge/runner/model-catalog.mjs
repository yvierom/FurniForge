import {spawn} from 'node:child_process';
import {writeFile,readFile} from 'node:fs/promises';
import {createInterface} from 'node:readline';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

export async function fetchModels(executable,{spawnProcess=spawn,timeoutMs=15000}={}){
 const child=spawnProcess(executable,['app-server'],{windowsHide:true,stdio:['pipe','pipe','pipe']});
 return new Promise((resolve,reject)=>{
  let done=false,id=2,models=[],seen=new Set();
  const finish=(err,value)=>{if(done)return;done=true;clearTimeout(timer);child.kill();err?reject(err):resolve(value);};
  const timer=setTimeout(()=>finish(Error('Codex model catalog timed out.')),timeoutMs);
  child.on('error',e=>finish(e));child.stdin.on('error',e=>finish(e));child.on('close',()=>finish(Error('Codex model catalog closed unexpectedly.')));
  child.stderr.resume();
  const send=x=>child.stdin.write(JSON.stringify(x)+'\n');
  createInterface({input:child.stdout}).on('line',line=>{
   let m;try{m=JSON.parse(line);}catch{return;}
   if(m.error){finish(Error('Codex model catalog unavailable.'));return;}
   if(m.id===1){send({method:'initialized',params:{}});send({id,method:'model/list',params:{limit:100,includeHidden:false}});return;}
   if(m.id!==id)return;
   for(const entry of m.result?.data||[]){const model=entry.model;if(entry.hidden||(Array.isArray(entry.inputModalities)&&!entry.inputModalities.includes('image'))||typeof model!=='string'||!/^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$/.test(model)||seen.has(model))continue;seen.add(model);models.push({id:model,name:typeof entry.displayName==='string'?entry.displayName.slice(0,120):model});}
   if(m.result?.nextCursor&&id<22){id++;send({id,method:'model/list',params:{limit:100,includeHidden:false,cursor:m.result.nextCursor}});}else finish(null,models);
  });
  send({id:1,method:'initialize',params:{clientInfo:{name:'furniforge',version:'0.4.2'},capabilities:{experimentalApi:true}}});
 });
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const task=JSON.parse(await readFile(process.argv[2],'utf8'));
 try{const models=await fetchModels(task.codex);await writeFile(task.output,JSON.stringify({status:'ready',models}));}
 catch(e){await writeFile(task.output,JSON.stringify({status:'error',message:String(e.message).slice(0,300)}));process.exitCode=1;}
}
