import {test} from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {PassThrough} from 'node:stream';
import {fetchModels} from '../sketchup/furniforge/runner/model-catalog.mjs';

test('loads every page and excludes hidden, text-only, and duplicate models',async()=>{
 const child=new EventEmitter();child.stdin=new PassThrough();child.stdout=new PassThrough();child.stderr=new PassThrough();child.kill=()=>{};let buffer='';
 child.stdin.on('data',data=>{buffer+=data.toString();let i;while((i=buffer.indexOf('\n'))>=0){const m=JSON.parse(buffer.slice(0,i));buffer=buffer.slice(i+1);const emit=result=>child.stdout.write(JSON.stringify({id:m.id,result})+'\n');if(m.method==='initialize')emit({});if(m.method==='model/list'&&!m.params.cursor)emit({data:[{model:'model-a',displayName:'Model A',inputModalities:['text','image']},{model:'text-only',inputModalities:['text']},{model:'hidden',hidden:true}],nextCursor:'page-2'});else if(m.method==='model/list')emit({data:[{model:'model-a'},{model:'model-b',displayName:'Model B'}],nextCursor:null});}});
 const models=await fetchModels('codex',{spawnProcess:()=>child});
 assert.deepEqual(models,[{id:'model-a',name:'Model A'},{id:'model-b',name:'Model B'}]);
});
