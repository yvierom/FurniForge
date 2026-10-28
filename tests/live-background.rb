# Run inside SketchUp. Preserves the user's request and geometry.
f=YvieroM::FurniForge
saved=Marshal.load(Marshal.dump(f.current_request))
original=Sketchup.active_model.entities.to_a
checks=[];uploaded=[]
check=lambda { |ok,label| raise label unless ok;checks<<label }
begin
 f.current_request.replace({values:{},references:[],request_id:SecureRandom.uuid,read_reference_ids:[]})
 png=File.binread(File.expand_path('../../FurniForge-v2-demo-perspective.png',__dir__))
 data='data:image/png;base64,'+Base64.strict_encode64(png)
 count=f.add_uploaded_references([{'name'=>'Front.png','data'=>data},{'name'=>'Side.png','data'=>data}])
 uploaded=f.current_request[:references].map { |r| r[:path] }
 check.call(count==2 && uploaded.uniq.length==2 && uploaded.all? { |p| File.binread(p)==png },'Two local images stored together with distinct IDs')
 check.call(f.request_info[:references].map { |r| r[:name] }==['Front.png','Side.png'],'Original filenames remain visible')
 before=f.current_request[:references].length
 begin
  f.add_uploaded_references([{'name'=>'Valid.png','data'=>data},{'name'=>'Invalid.png','data'=>'data:image/png;base64,AAAA'}]);raise 'Expected rejection'
 rescue => e
  raise unless e.message=='Invalid image data.'
 end
 check.call(f.current_request[:references].length==before,'Invalid batch adds no partial references')
 f.current_request[:references]=f.current_request[:references]*4
 begin
  f.add_uploaded_references([{'name'=>'Extra.png','data'=>data}]);raise 'Expected rejection'
 rescue => e
  raise unless e.message=='Maximum 8 reference images.'
 end
 check.call(f.current_request[:references].length==8,'Eight-image limit enforced in native backend')
 f.current_request[:references]=f.current_request[:references].first(2)
 f.prepare_model_request({'assistant'=>'GPT Codex','description'=>'Keep the curved armrest and timber legs.'})
 check.call(f.request_info[:values]['description']=='Keep the curved armrest and timber legs.','Additional description saved with request')
 check.call(f.launcher_info[:available],'Configured background launcher paths valid')
ensure
 uploaded.each { |p| File.delete(p) if File.file?(p) }
 f.current_request.replace(saved);f.push_panel
end
check.call(original==Sketchup.active_model.entities.to_a,'Existing model geometry preserved')
File.write(File.expand_path('../../FurniForge-v4-native-test-report.json',__dir__),JSON.pretty_generate({ok:true,checks:checks}))
