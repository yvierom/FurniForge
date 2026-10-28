// Copyright (c) 2026 yviero_m. All rights reserved.
// Generate local, mergeable MCP configuration snippets without editing assistant settings.
import {writeFile, mkdir, access, unlink} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
export function makeConfigs({node,server,state}) {
 for(const [key,value] of Object.entries({node,server,state})) if(typeof value!=='string'||!path.isAbsolute(value)) throw Error(`${key} must be an absolute path`);
 const entry={command:node,args:[server],env:{FURNIFORGE_STATE:state}};
 return {claude:{mcpServers:{furniforge:{type:'stdio',...entry}}},cursor:{mcpServers:{furniforge:entry}},gemini:{mcpServers:{furniforge:{...entry,trust:false}}}};
}
export async function writeConfigs({node,server,state,outdir}) {
 if(!path.isAbsolute(outdir)) throw Error('Output directory must be absolute');
 await Promise.all([access(node),access(server)]);
 const configs=makeConfigs({node,server,state});await mkdir(outdir,{recursive:true});
 const paths=[];
 try {
  for(const [provider,config] of Object.entries(configs)) {
   const file=path.join(outdir,`${provider}.furniforge.json`);
   await writeFile(file,JSON.stringify(config,null,2)+'\n',{flag:'wx'});paths.push(file);
  }
  return paths;
 } catch(error) { await Promise.all(paths.map(file=>unlink(file).catch(()=>{}))); throw error; }
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const args=process.argv.slice(2);if(args.length!==4){console.error('Usage: node integrations/prepare-config.mjs <absolute-node> <absolute-server> <absolute-bridge-state> <absolute-output-directory>');process.exitCode=2;}
 else writeConfigs({node:args[0],server:args[1],state:args[2],outdir:args[3]}).then(files=>console.log(JSON.stringify({files},null,2))).catch(e=>{console.error(e.message);process.exitCode=1;});
}
