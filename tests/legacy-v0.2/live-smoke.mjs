import assert from 'node:assert/strict';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { fileURLToPath } from 'node:url';
const client=new Client({name:'FurniForge integration test',version:'0.1.0'});
await client.connect(new StdioClientTransport({command:process.execPath,args:[fileURLToPath(new URL('../server/index.mjs',import.meta.url))],env:{...process.env},stderr:'pipe'}));
async function read(name,args={}){const r=await client.callTool({name,arguments:args});if(r.isError)throw new Error(r.content[0].text);return JSON.parse(r.content[0].text);}
try{
 const status=await read('furniforge_status');assert.equal(status.bridge_running,true);
 const request=await read('furniforge_get_request');
 const before=await read('furniforge_inspect_models');
 const op='furniforge_smoke_1200_700_750';
 const bad=await client.callTool({name:'furniforge_create_table',arguments:{operation_id:'invalid_geometry_test',width_mm:200,depth_mm:200,height_mm:750,leg_size_mm:150}});
 assert.equal(bad.isError,true);
 const table=await read('furniforge_create_table',{operation_id:op,width_mm:1200,depth_mm:700,height_mm:750});
 assert.deepEqual(table.dimensions_mm,{width:1200,depth:700,height:750});
 assert.equal(table.part_count,5);assert.equal(table.all_parts_solid,true);
 const repeated=await read('furniforge_create_table',{operation_id:op,width_mm:1200,depth_mm:700,height_mm:750});
 assert.equal(repeated.entity_id,table.entity_id);assert.equal(repeated.already_created,true);
 const after=await read('furniforge_inspect_models');
 assert.equal(after.models.length,before.models.length+(table.already_created?0:1));
 console.log(JSON.stringify({ok:true,sketchup:status.sketchup,manual_request:request.values,table,checks:['MCP initialization','live status','request reading','invalid geometry rejected','exact dimensions','five solid parts','idempotent retry']},null,2));
}finally{await client.close();}

