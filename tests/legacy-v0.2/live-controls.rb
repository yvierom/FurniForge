# Integration checks for the disposable ff_v2_custom_sofa_test fixture only.
# Run from SketchUp Ruby after tests/live-workflow.mjs. Does not accept a production job.
f=YvieroM::FurniForge
id='ff_v2_custom_sofa_test'
root,original=f.find_job(id)
raise 'Expected the FurniForge integration fixture' unless original.dig('manual','notes').to_s.include?('Integration-test fixture')
request=Marshal.load(Marshal.dump(f.current_request))
checks=[]
assert_ff=lambda { |condition,label| raise label unless condition; checks << label }
reject_ff=lambda do |pattern,&block|
  error=nil
  begin;block.call;rescue=>e;error=e.message;end
  raise "Expected rejection #{pattern}; got #{error.inspect}" unless error && error.match?(pattern)
  checks << "Rejected: #{pattern.source}"
end
begin
 f.current_request[:active_job]=id
 f.control_job('stop')
 reject_ff.call(/stopped or accepted/) { f.apply_parts({'job_id'=>id,'expected_revision'=>original['revision'],'parts'=>[original['parts']['base']]}) }
 f.control_job('revise','Test-only feedback: check checkpoint recovery.')
 changed=JSON.parse(JSON.generate(original['parts']['base']));changed['size_mm'][0]=1700
 result=f.apply_parts({'job_id'=>id,'expected_revision'=>original['revision'],'parts'=>[changed]})
 assert_ff.call(result['measurements']['manual_dimensions_match']==false,'Dimension discrepancy detected')
 assert_ff.call(result['previews'].empty?,'Geometry revision invalidates previews')
 reject_ff.call(/dimensions differ/) {f.request_review({'job_id'=>id,'expected_revision'=>result['revision'],'review_notes'=>'Test'})}
 restored=f.restore_job
 assert_ff.call(restored['measurements']['manual_dimensions_match'],'Checkpoint restores exact dimensions')
 revision=restored['revision']
 # First patch mutates a real part; second passes numeric validation but is below SketchUp face tolerance.
 tiny={'id'=>'tiny','name'=>'Tiny test','kind'=>'mesh','vertices_mm'=>[[0,0,0],[0.01,0,0],[0,0.01,0]],'triangles'=>[[0,1,2]]}
 reject_ff.call(/Mesh produced no faces/) {f.apply_parts({'job_id'=>id,'expected_revision'=>revision,'parts'=>[changed,tiny]})}
 after=f.job_summary(root)
 assert_ff.call(after['revision']==revision && after['measurements']['manual_dimensions_match'],'Atomic failure restores geometry and job revision')
 f.current_request[:values]=request[:values].merge('width_mm'=>1800)
 reject_ff.call(/Specifications changed/) {f.apply_parts({'job_id'=>id,'expected_revision'=>revision,'parts'=>[changed]})}
 f.current_request[:values]=request[:values]
 reject_ff.call(/reviewed model first/) {f.control_job('accept')}
 reject_ff.call(/Unknown FurniForge method/) {f.dispatch('accept',{})}
 reject_ff.call(/Unknown FurniForge method/) {f.dispatch('eval_ruby',{})}
 # UI-only acceptance transition tested against the fixture, then restored below.
 restored_job=f.find_job(id)[1];restored_job['stage']='review'
 restored_job['previews']=original['previews'];f.store_job(root,restored_job)
 assert_ff.call(f.control_job('accept')['stage']=='accepted','UI control accepts a reviewed fixture')
 reject_ff.call(/stopped or accepted/) {f.apply_parts({'job_id'=>id,'expected_revision'=>revision,'parts'=>[changed]})}
 f.control_job('revise','Return test fixture to user review.')
 assert_ff.call(f.find_job(id)[1]['stage']=='revising','User feedback resumes revision after acceptance')
ensure
 # Always restore only the explicitly named disposable fixture, including on test failure.
 model=Sketchup.active_model;model.start_operation('Restore FurniForge test fixture',true)
 root.definition.entities.erase_entities(root.definition.entities.to_a)
 original['parts'].each_value { |p| f.draw_part(root.definition.entities,p) }
 f.store_job(root,original)
 model.commit_operation
 f.current_request.replace(request)
 f.push_panel
end
File.write(File.expand_path('../../FurniForge-v2-controls-report.json',__dir__),JSON.pretty_generate({checks:checks,stage:f.find_job(id)[1]['stage']}))
checks
