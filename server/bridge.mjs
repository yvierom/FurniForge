import net from 'node:net';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { randomUUID } from 'node:crypto';
export function stateFile() {
  return process.env.FURNIFORGE_STATE || path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), '.local', 'share'), 'FurniForge', 'bridge.json');
}
export async function bridgeCall(method, params = {}, client = {name: 'FurniForge test client'}) {
  let state;
  try { state = JSON.parse(await readFile(stateFile(), 'utf8')); }
  catch { throw new Error('FurniForge bridge is unavailable. Open SketchUp and start the FurniForge extension.'); }
  if (state.host !== '127.0.0.1' || !Number.isInteger(state.port) || state.port < 1024 || state.port > 65535 || !/^[a-f0-9]{64}$/.test(state.token)) throw new Error('Invalid local bridge configuration.');
  const id = randomUUID();
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({host: '127.0.0.1', port: state.port});
    let chunks = '', bytes = 0, settled = false;
    const finish = (error, result) => { if (settled) return; settled = true; clearTimeout(deadline); socket.destroy(); error ? reject(error) : resolve(result); };
    const deadline = setTimeout(() => finish(new Error('SketchUp did not respond within 15 seconds. Close modal dialogs and retry. Inspect the scene before retrying model creation.')), 15000);
    socket.setEncoding('utf8');
    socket.on('connect', () => socket.write(JSON.stringify({id, token: state.token, method, params, client}) + '\n'));
    socket.on('data', data => {
      bytes += Buffer.byteLength(data);
      if (bytes > 8 * 1024 * 1024) return finish(new Error('Bridge response exceeds the limit.'));
      chunks += data;
      if (!chunks.includes('\n')) return;
      try {
        const message = JSON.parse(chunks.slice(0, chunks.indexOf('\n')));
        if (message.id !== id) throw new Error('Bridge response ID mismatch.');
        if (!message.ok) throw new Error(message.error || 'SketchUp rejected the request.');
        finish(null, message.result);
      } catch(error) { finish(error); }
    });
    socket.on('error', () => finish(new Error('Cannot connect to FurniForge in SketchUp. Start the bridge from Extensions > FurniForge.')));
    socket.on('end', () => { if (!settled) finish(new Error('Bridge connection closed without a response.')); });
  });
}

