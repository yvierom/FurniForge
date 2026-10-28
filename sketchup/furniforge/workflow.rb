# Copyright (c) 2026 yviero_m. All rights reserved.
# Declarative modelling: no Ruby evaluation or caller-supplied filesystem paths.
module YvieroM
  module FurniForge
    JOB_DICT = 'yviero_m.furniforge.workflow' unless const_defined?(:JOB_DICT)
    def self.job_roots
      Sketchup.active_model.entities.grep(Sketchup::ComponentInstance).select { |e| e.get_attribute(JOB_DICT,'state') }
    end
    def self.find_job(id)
      root = job_roots.find { |e| e.get_attribute(JOB_DICT,'id') == id }
      raise 'Job not found in the active model' unless root
      [root, JSON.parse(root.get_attribute(JOB_DICT,'state'))]
    end
    def self.store_job(root, job)
      root.set_attribute(JOB_DICT,'state',JSON.generate(job))
    end
    def self.mutable_job(id, revision)
      root, job = find_job(id)
      raise 'Exit component editing before changing a job' if Sketchup.active_model.active_path
      raise 'Job is stopped or complete; use the panel to request changes first' if %w[stopped accepted completed].include?(job['stage'])
      raise 'Stale revision. Read the job again.' unless revision == job['revision']
      raise 'Reference request changed. Start a new model from the current images.' if job['request_id'] && job['request_id'] != request_info[:request_id]
      raise 'Specifications changed. Create a new job to use the new manual inputs.' unless job['manual'] == current_request[:values]
      [root,job]
    end
    def self.create_job(params)
      raise 'Exit component editing first' if Sketchup.active_model.active_path
      id = params['job_id'].to_s
      raise 'Invalid job ID' unless id.match?(/\A[a-zA-Z0-9_-]{8,80}\z/)
      found = job_roots.find { |e| e.get_attribute(JOB_DICT,'id') == id }
      return job_summary(found) if found
      req=current_request
      refs=req[:references]
      raise 'Attach a reference image before creating a model' if refs.empty?
      raise 'Request changed. Read the current request again.' unless params['request_id']==request_info[:request_id]
      raise 'Read the attached reference images before modelling' unless refs.all? { |r| (req[:read_reference_ids] || []).include?(r[:id]) }
      plan = params.fetch('plan','Build furniture from the attached reference images.').to_s
      raise 'Provide a modelling plan (max 6000 characters)' unless plan.length.between?(1,6000)
      assumptions = params.fetch('assumptions',[])
      raise 'Too many assumptions' unless assumptions.is_a?(Array) && assumptions.length <= 30
      assumptions.each do |a|
        raise 'Invalid assumption' unless a.is_a?(Hash) && a['field'].is_a?(String) && a['value'].is_a?(String) && a['reason'].is_a?(String)
        raise 'Assumption too long' if a.values.any? { |v| !v.is_a?(String) || v.length > 1000 }
        raise 'Do not re-estimate a manual field' if current_request[:values].key?(a['field'])
      end
      model=Sketchup.active_model
      b=model.bounds
      origin=b.empty? ? [0,0,0] : [b.max.x+500.mm,b.min.y,0]
      model.start_operation('FurniForge: Start modelling job',true)
      begin
        definition=model.definitions.add("FurniForge #{id}")
        # SketchUp deletes empty definitions on commit; retain a hidden planning marker.
        definition.entities.add_cpoint(ORIGIN).hidden=true
        root=model.entities.add_instance(definition,Geom::Transformation.translation(origin))
        root.name=current_request[:values].fetch('name','FurniForge custom model')
        root.set_attribute(JOB_DICT,'id',id)
        job={'id'=>id,'stage'=>'planning','revision'=>0,'plan'=>plan,'assumptions'=>assumptions,
          'request_id'=>request_info[:request_id],'reference_images'=>refs.map { |r| {id:r[:id],name:r[:name]} },
          'manual'=>current_request[:values].dup,'parts'=>{},'history'=>[],'previews'=>{},
          'feedback'=>[],'created_at'=>Time.now.utc.iso8601,'log'=>['Job created; no geometry built yet']}
        store_job(root,job)
        model.commit_operation
        current_request[:active_job]=id
        current_request[:generation]={status:'building',job_id:id}
        push_panel
        job_summary(root)
      rescue
        model.abort_operation
        raise
      end
    end
    def self.job_summary(root, include_parts=false)
      job=JSON.parse(root.get_attribute(JOB_DICT,'state'))
      out=job.reject { |k,_| %w[history parts].include?(k) }
      out['history_revisions']=job['history'].map { |h| h['revision'] }
      out['part_count']=job['parts'].length
      out['parts']=job['parts'] if include_parts
      out['measurements']=measure_job(root,job)
      out
    end
    def self.measure_job(root,job)
      parts=root.definition.entities.grep(Sketchup::Group)
      bb=root.definition.bounds
      actual={'width_mm'=>bb.empty? ? 0 : bb.width.to_mm,'depth_mm'=>bb.empty? ? 0 : bb.height.to_mm,'height_mm'=>bb.empty? ? 0 : bb.depth.to_mm}
      checks={}
      %w[width_mm depth_mm height_mm].each do |key|
        expected=job['manual'][key]
        checks[key]={'actual'=>actual[key].round(3),'expected'=>expected,'matches'=>expected.nil? ? nil : (actual[key]-expected).abs <= 1.0}
      end
      face_count=parts.sum { |g| g.entities.grep(Sketchup::Face).length }
      {'dimensions'=>checks,'faces'=>face_count,'parts'=>parts.length,
       'non_solid_parts'=>parts.reject(&:manifold?).map(&:name),
       'manual_dimensions_match'=>checks.values.all? { |c| c['matches'] != false },
       'all_dimensions_provided'=>checks.values.all? { |c| !c['expected'].nil? },
       'scale_note'=>checks.values.all? { |c| !c['expected'].nil? } ? 'Manual overall dimensions' : 'Unspecified dimensions use approximate model scale.',
       'fidelity'=>'Built by the assistant from reference images; visual similarity is not automatically scored.'}
    end
    def self.valid_vector(v, limit=20000)
      raise 'Expected three finite numbers' unless v.is_a?(Array) && v.length==3 && v.all? { |n| n.is_a?(Numeric) && n.finite? && n.abs<=limit }
      v
    end
    def self.validate_part(p)
      raise 'Invalid part' unless p.is_a?(Hash)
      raise 'Invalid part ID' unless p['id'].is_a?(String) && p['id'].match?(/\A[a-zA-Z0-9_-]{1,64}\z/)
      raise 'Invalid part name' unless p['name'].is_a?(String) && p['name'].length.between?(1,120)
      valid_vector(p.fetch('position_mm',[0,0,0]))
      valid_vector(p.fetch('rotation_deg',[0,0,0]),360)
      raise 'Invalid colour' unless p.fetch('color','#d8d5cc').match?(/\A#[0-9a-fA-F]{6}\z/)
      case p['kind']
      when 'box'
        valid_vector(p['size_mm'])
        raise 'Box dimensions must be positive' unless p['size_mm'].all? { |n| n>=0.1 }
      when 'mesh'
        vs=p['vertices_mm']; fs=p['triangles']
        raise 'Mesh limit: 3..10000 vertices, 1..20000 triangles per part' unless vs.is_a?(Array) && vs.length.between?(3,10000) && fs.is_a?(Array) && fs.length.between?(1,20000)
        vs.each { |v| valid_vector(v) }
        fs.each do |f|
          raise 'Invalid zero-based triangle indices' unless f.is_a?(Array) && f.length==3 && f.uniq.length==3 && f.all? { |i| i.is_a?(Integer) && i>=0 && i<vs.length }
          a,b,c=f.map { |i| Geom::Point3d.new(vs[i]) }
          raise 'Degenerate triangle' if (b-a).cross(c-a).length.to_f < 0.00001
        end
      else raise 'Part kind must be box or mesh'
      end
    end
    def self.draw_part(entities,p)
      if p['kind']=='box'
        w,d,h=p['size_mm'].map(&:mm)
        group=box(entities,p['name'],[0,0,0],w,d,h)
      else
        group=entities.add_group
        group.name=p['name']
        mesh=Geom::PolygonMesh.new(p['vertices_mm'].length,p['triangles'].length)
        ids=p['vertices_mm'].map { |v| mesh.add_point(Geom::Point3d.new(v.map(&:mm))) }
        p['triangles'].each { |f| mesh.add_polygon(f.map { |i| ids[i] }) }
        flags=p.fetch('smooth',true) ? Geom::PolygonMesh::AUTO_SOFTEN | Geom::PolygonMesh::SMOOTH_SOFT_EDGES : 0
        group.entities.fill_from_mesh(mesh,true,flags)
        raise 'Mesh produced no faces' if group.entities.grep(Sketchup::Face).empty?
      end
      color=p.fetch('color','#d8d5cc')
      group.entities.grep(Sketchup::Face).each do |face|
        face.material=color
        face.back_material=color
      end
      group.set_attribute(JOB_DICT,'part_id',p['id'])
      tr=Geom::Transformation.translation(p.fetch('position_mm',[0,0,0]).map(&:mm))
      p.fetch('rotation_deg',[0,0,0]).each_with_index do |angle,index|
        axis=[0,0,0];axis[index]=1
        tr=tr*Geom::Transformation.rotation(ORIGIN,axis,angle.degrees)
      end
      group.transformation=tr
      group
    end
    def self.apply_parts(params)
      root,job=mutable_job(params['job_id'],params['expected_revision'])
      patches=params.fetch('parts',[])
      remove=params.fetch('remove_part_ids',[])
      raise 'Use 1..20 changes per batch' unless patches.is_a?(Array) && remove.is_a?(Array) && (patches.length+remove.length).between?(1,20)
      patches.each { |p| validate_part(p) }
      ids=patches.map { |p| p['id'] }
      raise 'Duplicate or conflicting part IDs' unless ids.uniq==ids && (ids & remove).empty?
      raise 'Cannot remove an unknown part' unless remove.all? { |id| job['parts'].key?(id) }
      prospective=job['parts'].merge(patches.to_h { |p| [p['id'],p] }).reject { |id,_| remove.include?(id) }
      faces=prospective.values.sum { |p| p['kind']=='box' ? 12 : p['triangles'].length }
      raise 'Job limit: 500 parts and 200000 triangles' if prospective.length>500 || faces>200000
      raise 'Batch triangle limit is 20000; split the update into smaller batches' if patches.sum { |p| p['kind']=='mesh' ? p['triangles'].length : 12 } > 20000
      model=Sketchup.active_model
      model.start_operation('FurniForge: Revise model parts',true)
      begin
        # Per-job definitions are unique. Replacing parts cannot alter unrelated scene objects.
        root.make_unique if root.definition.instances.length>1
        root.definition.entities.grep(Sketchup::Group).each do |g|
          g.erase! if (ids+remove).include?(g.get_attribute(JOB_DICT,'part_id'))
        end
        root.definition.entities.grep(Sketchup::ConstructionPoint).each(&:erase!)
        patches.each { |p| draw_part(root.definition.entities,p) }
        root.definition.entities.add_cpoint(ORIGIN).hidden=true if prospective.empty?
        job['history'] << {'revision'=>job['revision'],'parts'=>job['parts']}
        job['history']=job['history'].last(5)
        job['parts']=prospective
        job['revision']+=1;job['stage']='building';job['previews']={}
        job['log']=(job['log']+["Revision #{job['revision']}: updated #{patches.length}, removed #{remove.length} parts"]).last(30)
        store_job(root,job)
        model.commit_operation
        # Show the new component when the first geometry appears; existing scene objects remain untouched.
        begin; model.active_view.zoom(root) if job['revision']==1 && !prospective.empty?; rescue => e; @last_error="Could not frame model: #{e.message}"; end
        push_panel
        job_summary(root)
      rescue
        model.abort_operation
        raise
      end
    end
    def self.capture_job(params)
      root,job=find_job(params['job_id'])
      raise 'No geometry to preview' if job['parts'].empty?
      view_name=params.fetch('view','perspective')
      vectors={'perspective'=>[1,-1,0.7],'front'=>[0,-1,0],'back'=>[0,1,0],'top'=>[0,0,1]}
      direction=vectors[view_name];raise 'Invalid view' unless direction
      model=Sketchup.active_model;view=model.active_view
      current_camera=view.camera
      camera=Sketchup::Camera.new(current_camera.eye,current_camera.target,current_camera.up,current_camera.perspective?)
      camera.aspect_ratio=current_camera.aspect_ratio
      if current_camera.perspective?
        camera.fov=current_camera.fov
      else
        camera.height=current_camera.height
      end
      raise 'Exit component editing before preview' if model.active_path
      folder=File.join(File.dirname(state_path),'previews',job['id'])
      FileUtils.mkdir_p(folder)
      file=File.join(folder,"r#{job['revision']}_#{view_name}.png")
      bb=root.bounds;target=bb.center;radius=[bb.width,bb.height,bb.depth,100.mm].max
      eye=target+Geom::Vector3d.new(direction.map { |n| n*radius*3 })
      hidden=model.entities.select { |e| e.respond_to?(:hidden?) && e!=root }.map { |e| [e,e.hidden?] }
      root_hidden=root.hidden?
      # Temporary presentation changes are restored even if capture fails.
      begin
        hidden.each { |e,_| e.hidden=true }
        root.hidden=false
        view.camera=Sketchup::Camera.new(eye,target,view_name=='top' ? [0,1,0] : [0,0,1],false)
        # Fit to the export aspect ratio, not the current SketchUp viewport.
        cam=view.camera
        projected=(0..7).map { |i| delta=bb.corner(i)-target; [delta.dot(cam.xaxis),delta.dot(cam.yaxis)] }
        span_x=projected.map(&:first).max-projected.map(&:first).min
        span_y=projected.map(&:last).max-projected.map(&:last).min
        cam.height=[span_y,span_x/(1000.0/750),1.mm].max*1.15
        view.camera=cam
        raise 'Preview capture failed' unless view.write_image(filename:file,width:1000,height:750,antialias:true)
      ensure
        hidden.each { |e,h| e.hidden=h if e.valid? }
        root.hidden=root_hidden
        view.camera=camera
      end
      job['previews'][view_name]={'revision'=>job['revision'],'path'=>file}
      store_job(root,job)
      data=Base64.strict_encode64(File.binread(file))
      @last_preview={'job_id'=>job['id'],'revision'=>job['revision'],'data'=>data}
      push_panel
      {mimeType:'image/png',data:data,job_id:job['id'],revision:job['revision'],view:view_name}
    end
    def self.finish_model(params)
      root,job=mutable_job(params['job_id'],params['expected_revision'])
      report=measure_job(root,job)
      raise 'No geometry has been created' if report['parts']==0 || report['faces']==0
      raise 'Model dimensions differ from supplied values; correct them first' unless report['manual_dimensions_match']
      summary=params.fetch('summary','Model created from the reference images.').to_s
      raise 'Summary must be 1..4000 characters' unless summary.length.between?(1,4000)
      job['stage']='completed';job['summary']=summary
      job['log']=(job['log']+['Model created in SketchUp']).last(30)
      store_job(root,job)
      current_request[:generation]={status:'completed',job_id:job['id']}
      begin; Sketchup.active_model.active_view.zoom(root); rescue => e; @last_error="Could not frame model: #{e.message}"; end
      push_panel('Model created directly in SketchUp.')
      job_summary(root)
    end
    # Compatibility for clients still holding the previous tool list.
    def self.request_review(params)
      finish_model(params.merge('summary'=>params.fetch('review_notes','Model created.')))
    end
    def self.control_job(action,feedback='')
      id=current_request[:active_job]
      raise 'Select or create a job first' unless id
      root,job=find_job(id)
      case action
      when 'stop'
        raise 'Accepted job is already complete' if job['stage']=='accepted'
        job['stage']='stopped'
      when 'revise'
        raise 'Enter the requested changes' if feedback.to_s.strip.empty?
        raise 'Feedback too long' if feedback.length>4000
        job['stage']='revising';job['feedback'] << feedback
      when 'accept'
        raise 'The assistant must submit a reviewed model first' unless job['stage']=='review'
        raise 'Specifications changed since this job started' unless job['manual']==current_request[:values]
        report=measure_job(root,job)
        raise 'Manual dimensions do not match' unless report['manual_dimensions_match']
                job['stage']='accepted'
      else raise 'Unknown control action'
      end
      store_job(root,job);push_panel("Job #{job['stage']}.")
      job_summary(root)
    end
    def self.restore_job
      root,job=mutable_job(current_request[:active_job],find_job(current_request[:active_job])[1]['revision'])
      previous=job['history'].last
      raise 'No checkpoint available' unless previous
      model=Sketchup.active_model;model.start_operation('FurniForge: Restore checkpoint',true)
      begin
        root.make_unique if root.definition.instances.length>1
        root.definition.entities.erase_entities(root.definition.entities.to_a)
        previous['parts'].each_value { |p| draw_part(root.definition.entities,p) }
        root.definition.entities.add_cpoint(ORIGIN).hidden=true if previous['parts'].empty?
        job['parts']=previous['parts'];job['history'].pop
        job['revision']+=1;job['stage']='revising';job['previews']={}
        job['log']=(job['log']+["Restored checkpoint #{previous['revision']} as revision #{job['revision']}"]).last(30)
        store_job(root,job);model.commit_operation;push_panel('Checkpoint restored.')
        job_summary(root)
      rescue
        model.abort_operation;raise
      end
    end
    def self.export_job
      root,job=find_job(current_request[:active_job])
      raise 'No geometry to export yet' if job['parts'].empty?
      path=UI.savepanel('Export FurniForge component','','FurniForge-'+job['id']+'.skp')
      return unless path
      path += '.skp' unless File.extname(path).downcase=='.skp'
      raise 'Export failed' unless root.definition.save_as(path)
      push_panel('Component exported.')
    end
  end
end



