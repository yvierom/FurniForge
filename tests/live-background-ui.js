(async()=>{
 const checks=[];const check=(v,label)=>{if(!v)throw Error(label);checks.push(label);};
 try{
  const s=JSON.parse(JSON.stringify(state));s.request.values={};s.request.references=[];s.job=null;s.launcher={available:true,run:{status:'idle'}};hydrated=false;receiveState(s,null);
  $('start').click();check(!$('assistants').hidden,'Logo opens assistant selection');
  check($('assistant-grid').children.length===4,'Four assistant choices');$('assistant-grid').children[0].click();
  check(!$('workspace').hidden,'Assistant opens workspace');
  check(!$('model-select')&&!$('handoff')&&!$('export')&&!!$('description'),'Description replaces model output and manual handoff');
  check($('demo-files').multiple,'Local picker accepts multiple files');
  $('generate').click();check($('message').textContent.includes('reference images'),'Images required before generation');
  const dt=new DataTransfer();dt.items.add(new File(['image-one'],'Front.png',{type:'image/png'}));dt.items.add(new File(['image-two'],'Side.png',{type:'image/png'}));
  $('demo-files').files=dt.files;await $('demo-files').onchange();
  check(pending==='upload','Batch upload waits for native acknowledgement');
  s.request.references=[{id:'front',name:'Front.png'},{id:'side',name:'Side.png'}];receiveState(s,'2 reference images added.');
  check($('references').children.length===2,'Both images listed after upload');
  $('description').value='Keep the curved armrest.';check(values().description==='Keep the curved armrest.','Description included in form values');
  check($('brief').checkValidity(),'All additional details remain optional');
  $('generate').click();check(!pending&&$('message').textContent.includes('Allow'),'Background session requires explicit opt-in');
  $('allow-background').checked=true;$('generate').click();check(pending==='generate','Create model submits automatic background request');
  s.launcher.run={status:'starting',message:'Starting Codex…'};receiveState(s,'Starting');check($('generate').disabled&&$('description').disabled&&!$('cancel-run').hidden,'Starting locks input and exposes Stop');
  s.launcher.run={status:'running',session_id:'test-session',message:'Working in SketchUp'};receiveState(s,null);check($('session-id').textContent.includes('test-session'),'Actual session identifier displayed');$('cancel-run').click();
  s.launcher.run={status:'waiting_approval',approval:{token:'approval-test',tool:'furniforge_apply_parts',message:'Allow geometry?',arguments:{job_id:'job-test',parts:[{id:'seat'}]}},message:'Waiting'};receiveState(s,null);
  check(!$('approval-panel').hidden&&$('approval-arguments').textContent.includes('job-test'),'Real approval prompt and parameters visible');$('approve-action').click();check(approvalSubmitted==='approval-test'&&$('approve-action').disabled,'Decision is sent only once');
  s.launcher.run={status:'failed',message:'Sign in required'};receiveState(s,'Session failed');check($('run-message').textContent==='Sign in required'&&!$('generate').disabled,'Failure shows error and releases inputs');
  setAssistant('Claude Code');check($('generate').disabled&&$('run-status').textContent.includes('not connected'),'Unsupported automatic provider labelled honestly');
  setAssistant('GPT Codex');$('setup-button').click();check($('setup').open,'Setup guide opens');$('close-setup').click();
  window.sketchup.test_result(JSON.stringify({ok:true,checks}));
 }catch(e){window.sketchup.test_result(JSON.stringify({ok:false,checks,error:e.message}));}
})();
