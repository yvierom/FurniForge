(()=>{
 const checks=[];const check=(v,label)=>{if(!v)throw Error(label);checks.push(label);};
 try{
  const blank=JSON.parse(JSON.stringify(state));blank.request.values={};blank.request.references=[];blank.request.generation=null;blank.job=null;hydrated=false;window.receiveState(blank,null);
  $('start').click();check(!$('assistants').hidden,'Logo opens assistant selection');
  check($('assistant-grid').children.length===4,'Four assistant choices');
  $('assistant-grid').children[0].click();check(!$('workspace').hidden,'Assistant opens modelling workspace');
  check(document.querySelectorAll('.flow > article').length===3,'Three focused workflow nodes');
  check(!$('optional-details').open,'Optional details start collapsed');
  check(!$('accept')&&!$('reviewed')&&!$('brief').querySelector('[required]'),'No approval controls or mandatory detail fields');
  $('generate').click();check($('message').textContent.includes('reference image first'),'Empty image input shows helpful message');
  const next=JSON.parse(JSON.stringify(state));next.request.references=[{id:'ui-test-reference',name:'Test furniture.png'}];window.receiveState(next,null);
  check($('brief').reportValidity(),'All detail fields may be blank');
  check($('references').textContent.includes('Test furniture.png'),'Attached reference listed');
  const input=$('brief').elements.namedItem('width_mm');input.value='700';input.dispatchEvent(new Event('input',{bubbles:true}));
  input.value='';input.dispatchEvent(new Event('input',{bubbles:true}));
  $('generate').click();check(pending==='generate','Create model sends native generation request without separate Save');
  next.request.request_id='ui-request';next.request.generation={status:'waiting_for_assistant'};window.receiveState(next,'Request ready.');
  check(!$('handoff').hidden&&$('handoff-text').value.includes('each attached image first'),'Handoff instructs assistant to read images');
  check($('handoff-text').value.includes('approximate scale')&&$('handoff-text').value.includes('furniforge_finish_model'),'Handoff allows image-only modelling and completion');
  check($('message').textContent.includes('Copy and send'),'Handoff does not claim AI has started');
  next.job={id:'ui-test-job',stage:'completed',revision:1,part_count:1,assumptions:[],summary:'Test model',measurements:{dimensions:{width_mm:{actual:700,expected:null,matches:null}},scale_note:'Approximate scale'}};window.receiveState(next,null);
  check(!$('export').disabled,'Completed geometry can export without acceptance');
  check($('scale-note').textContent==='Approximate scale','Approximate scale disclosed');
  $('setup-button').click();check($('setup').open,'Setup guide available');$('close-setup').click();
  window.sketchup.test_result(JSON.stringify({ok:true,checks}));
 }catch(e){window.sketchup.test_result(JSON.stringify({ok:false,checks,error:e.message}));}
})();
