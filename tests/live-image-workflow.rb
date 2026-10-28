# Run in SketchUp Ruby with FurniForge 0.3 loaded. Temporary fixtures are removed in ensure.
f=YvieroM::FurniForge
saved=Marshal.load(Marshal.dump(f.current_request))
original_entities=Sketchup.active_model.entities.to_a
ids=[];checks=[]
check=lambda { |value,label| raise label unless value;checks<<label }
reject=lambda do |pattern,&block|
 error=nil;begin;block.call;rescue=>e;error=e.message;end
 raise "Expected #{pattern}, got #{error.inspect}" unless error && error.match?(pattern)
 checks<<"Rejected: #{pattern.source}"
end
ref_path=File.expand_path('../../FurniForge-v2-demo-perspective.png',__dir__)
output=File.expand_path('../../../work/v3-export-test.skp',__dir__)
ui_singleton=class << UI; self; end
original_savepanel=UI.method(:savepanel)
begin
 f.current_request.replace({values:{},references:[],request_id:SecureRandom.uuid,read_reference_ids:[]})
 check.call(f.request_info[:missing_required]==['reference_image'],'Only reference image is required')
 reject.call(/Attach a reference image/) {f.create_job({'job_id'=>'ff_v3_no_reference','request_id'=>f.request_info[:request_id]})}
 f.current_request[:references]=[{id:'test-reference',name:'Synthetic test reference.png',path:ref_path}]
 request=f.prepare_model_request({})
 check.call(request[:generation][:status]=='waiting_for_assistant','Create request saves image-only input without a separate Save step')
 check.call(f.request_info[:missing_required].empty?,'Blank dimensions do not block image input')
 reject.call(/Read the attached reference/) {f.create_job({'job_id'=>'ff_v3_unread_reference','request_id'=>f.request_info[:request_id]})}
 img=f.read_reference('test-reference')
 check.call(img[:mimeType]=='image/png' && img[:data].length>100,'Attached image delivered as image data')
 id='ff_v3_image_only_test';ids<<id
 job=f.create_job({'job_id'=>id,'request_id'=>f.request_info[:request_id]})
 check.call(job['manual'].empty? && job['reference_images'].length==1,'Model starts from image with all detail fields blank')
 part={'id'=>'test_part','name'=>'Temporary test block','kind'=>'box','size_mm'=>[100,80,50]}
 job=f.apply_parts({'job_id'=>id,'expected_revision'=>0,'parts'=>[part]})
 done=f.finish_model({'job_id'=>id,'expected_revision'=>1,'summary'=>'Synthetic fixture, approximate scale; tests bridge mechanics only.'})
 check.call(done['stage']=='completed','Model completes without dimensions, three-view gate or user approval')
 check.call(done['measurements']['scale_note'].include?('approximate'),'Approximate scale is disclosed')
 ui_singleton.send(:define_method,:savepanel) { |*args| output }
 f.export_job
 check.call(File.exist?(output) && File.size(output)>100,'Component exports without approval gate')
 ui_singleton.send(:define_method,:savepanel,original_savepanel)
 f.save_request({'width_mm'=>80})
 id='ff_v3_partial_dimensions';ids<<id
 job=f.create_job({'job_id'=>id,'request_id'=>f.request_info[:request_id]})
 f.apply_parts({'job_id'=>id,'expected_revision'=>0,'parts'=>[part]})
 reject.call(/dimensions differ from supplied/) {f.finish_model({'job_id'=>id,'expected_revision'=>1})}
 part['size_mm']=[80,80,50]
 f.apply_parts({'job_id'=>id,'expected_revision'=>1,'parts'=>[part]})
 done=f.finish_model({'job_id'=>id,'expected_revision'=>2})
 check.call(done['stage']=='completed','One manual dimension is preserved; other dimensions remain optional')
 f.control_job('revise','Temporary test update')
 f.current_request[:request_id]=SecureRandom.uuid
 reject.call(/Reference request changed/) {f.apply_parts({'job_id'=>id,'expected_revision'=>2,'parts'=>[part]})}
 reject.call(/Request changed/) {f.create_job({'job_id'=>'ff_v3_old_request','request_id'=>'stale'})}
ensure
 ui_singleton.send(:define_method,:savepanel,original_savepanel)
 model=Sketchup.active_model;model.start_operation('Remove FurniForge test fixtures',true)
 f.job_roots.each { |r| r.erase! if ids.include?(r.get_attribute(f::JOB_DICT,'id')) }
 model.commit_operation
 f.current_request.replace(saved);f.push_panel
end
check.call(original_entities.all?(&:valid?) && Sketchup.active_model.entities.length==original_entities.length,'Existing scene preserved; temporary fixtures removed')
File.write(File.expand_path('../../FurniForge-v3-test-report.json',__dir__),JSON.pretty_generate({ok:true,checks:checks}))
