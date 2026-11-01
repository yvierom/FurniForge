import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { fileURLToPath } from 'node:url';
const script = fileURLToPath(new URL('../server/index.mjs',import.meta.url));
test('MCP initializes, lists bounded tools, validates input and reports unavailable bridge',async()=>{
 const client=new Client({name:'FurniForge protocol test',version:'0.4.0'});
 const transport=new StdioClientTransport({command:process.execPath,args:[script],env:{...process.env,FURNIFORGE_STATE:script+'.missing'},stderr:'pipe'});
 await client.connect(transport);
 try {
  const list=await client.listTools();
  assert.equal(list.tools.length,8);
  const views=list.tools.find(t=>t.name==='furniforge_capture_preview').inputSchema.properties.view.enum;
  assert.ok(['perspective','front','bottom','left','right'].every(view=>views.includes(view)));
  const geometry=list.tools.find(t=>t.name==='furniforge_apply_parts').inputSchema;
  const position=geometry.properties.parts.items.properties.position_mm;
  assert.equal(position.type,'array');assert.equal(position.minItems,3);assert.equal(position.maxItems,3);
  assert.equal(position.items.type,'number');
  const material=geometry.properties.parts.items.properties.material;
  assert.deepEqual(material.properties.preset.enum,['fabric','wood']);
  assert.equal(material.properties.roughness.minimum,0);
  assert.equal(material.properties.roughness.maximum,1);
  const invalidMaterial=await client.callTool({name:'furniforge_apply_parts',arguments:{job_id:'test_vectors',expected_revision:0,parts:[{id:'seat',name:'Seat',kind:'box',size_mm:[10,10,10],material:{preset:'fabric',roughness:2}}]}});
  assert.equal(invalidMaterial.isError,true);
  const invalidVector=await client.callTool({name:'furniforge_apply_parts',arguments:{job_id:'test_vectors',expected_revision:0,parts:[{id:'leg',name:'Leg',kind:'box',position_mm:[1,2],size_mm:[10,10,10]}]}});
  assert.equal(invalidVector.isError,true);
  assert.match(invalidVector.content[0].text,/3|position_mm/);
  assert.ok(!list.tools.some(t=>/eval|execute_ruby/.test(t.name)));
  const status=await client.callTool({name:'furniforge_status',arguments:{}});
  assert.equal(status.isError,true);
  assert.match(status.content[0].text,/unavailable/);
  assert.ok(list.tools.some(t=>t.name==='furniforge_finish_model'));
  assert.ok(!list.tools.some(t=>/create_table|request_review/.test(t.name)));
  const invalid=await client.callTool({name:'furniforge_create_job',arguments:{job_id:'test_invalid'}});
  assert.equal(invalid.isError,true);
 } finally {await client.close();}
});



