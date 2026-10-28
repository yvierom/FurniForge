(()=>{
 const checks=[];const assert=(condition,label)=>{if(!condition)throw Error(label);checks.push(label);};
 const original=state;const originalValues=values();
 try{
  $('start').click();assert(!$('assistants').hidden,'Logo opens assistant selection');
  assert($('assistant-grid').children.length===4,'Four assistant choices');
  assert([...$('assistant-grid').querySelectorAll('img')].every(i=>i.complete&&i.naturalWidth>0),'All assistant icons loaded');
  $('assistant-grid').children[0].click();assert(!$('workspace').hidden,'Assistant opens visual workflow');
  assert($('bridge-status').textContent.includes('available'),'Native bridge state displayed');
  assert($('demo').hidden,'Simulated job control hidden in SketchUp');
  $('reviewed').checked=true;$('reviewed').dispatchEvent(new Event('change'));
  assert(!$('accept').disabled,'Inspected reviewed fixture enables acceptance');
  window.receiveState({...original,job:{...original.job,revision:original.job.revision+1}},null);
  assert(!$('reviewed').checked&&$('accept').disabled,'New revision resets user inspection acknowledgement');
  window.receiveState(original,null);
  const width=$('brief').elements.namedItem('width_mm');width.value='1601';width.dispatchEvent(new Event('input',{bubbles:true}));
  $('prepare').click();assert($('message').textContent.includes('Save your brief'),'Unsaved edits block modelling handoff');
  width.value=originalValues.width_mm;dirty=false;savedOnce=true;fieldStatus();
  $('prepare').click();assert(!$('handoff').hidden&&$('handoff-text').value.includes('manual values unchanged'),'Prepared request preserves manual values');
  $('setup-button').click();assert($('setup').open,'Setup guide opens');$('close-setup').click();assert(!$('setup').open,'Setup guide closes');
  assert(document.fonts.check('14px DM'),'Bundled DM Sans loaded');
  const board=document.querySelector('.board');assert(board.clientHeight<board.scrollHeight,'Workflow has contained vertical scrolling');
  window.sketchup.test_result(JSON.stringify({ok:true,checks}));
 }catch(e){window.sketchup.test_result(JSON.stringify({ok:false,checks,error:e.message}));}
 finally {hydrated=false;dirty=false;window.receiveState(original,null);$('handoff').hidden=true;message('Ready for your review. This sofa is an integration-test example.');}
})();
