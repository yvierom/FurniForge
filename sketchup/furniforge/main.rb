# Copyright (c) 2026 yviero_m. All rights reserved.
require 'sketchup.rb'
require 'json'
require 'time'
require 'socket'
require 'securerandom'
require 'fileutils'
require 'base64'

module YvieroM
  module FurniForge
    VERSION = '0.4.2' unless const_defined?(:VERSION)
    DICT = 'yviero_m.furniforge' unless const_defined?(:DICT)

    def self.state_path
      ENV['FURNIFORGE_STATE'] || File.join(ENV['LOCALAPPDATA'] || File.join(Dir.home, '.local', 'share'), 'FurniForge', 'bridge.json')
    end

    def self.start
      return if @server
      @clients = {}
      @server = TCPServer.new('127.0.0.1', 0)
      @token = SecureRandom.hex(32)
      FileUtils.mkdir_p(File.dirname(state_path))
      File.write(state_path, JSON.generate({host:'127.0.0.1',port:@server.addr[1],token:@token,pid:Process.pid,version:VERSION}))
      @timer = UI.start_timer(0.05, true) { tick }
      @last_error = nil
    rescue => e
      stop
      @last_error = e.message
      raise
    end

    def self.stop
      UI.stop_timer(@timer) if @timer
      @timer = nil
      (@clients || {}).each_key { |sock| sock.close rescue nil }
      @clients = {}
      @server.close if @server
      @server = nil
      if File.exist?(state_path)
        saved = JSON.parse(File.read(state_path)) rescue {}
        File.delete(state_path) if saved['token'] == @token
      end
    end

    def self.tick
      4.times do
        sock = @server.accept_nonblock(exception:false)
        break if sock == :wait_readable
        if @clients.length >= 12
          sock.close
        else
          @clients[sock] = {input: ''.b, output:nil, at:Time.now}
        end
      end
      @clients.keys.each do |sock|
        item = @clients[sock]
        begin
          raise 'Connection expired' if Time.now - item[:at] > 12
          if item[:output]
            n = sock.write_nonblock(item[:output], exception:false)
            next if n == :wait_writable
            item[:output] = item[:output].byteslice(n..-1)
            close_client(sock) if item[:output].empty?
            next
          end
          chunk = sock.read_nonblock(262144, exception:false)
          next if chunk == :wait_readable
          if chunk.nil?
            close_client(sock)
            next
          end
          item[:input] << chunk
          raise 'Request too large (2 MB)' if item[:input].bytesize > 2 * 1024 * 1024
          if item[:input].include?("\n")
            request = JSON.parse(item[:input].split("\n",2).first.force_encoding('UTF-8'))
            raise 'Authentication failed' unless request['token'] == @token
            unless request.dig('client','health_probe')==true
              @last_caller = (request.dig('client','name') || 'Unknown MCP client').to_s[0,100]
              @last_seen = Time.now
            end
            begin
              scope=request.dig('client','request_id')
              raise 'This background request is no longer active.' if scope && scope != request_info[:request_id]
              if scope && scope == request_info[:request_id]
                @background_seen_request_id=scope
                @background_seen_at=Time.now
              end
              result = dispatch(request['method'], request['params'] || {})
              response = {id:request['id'],ok:true,result:result}
            rescue => e
              response = {id:request['id'],ok:false,error:e.message}
            end
            item[:output] = (JSON.generate(response) + "\n").b
          end
        rescue
          close_client(sock)
        end
      end
    rescue => e
      @last_error = e.message
    end

    def self.close_client(sock)
      @clients.delete(sock)
      sock.close rescue nil
    end

    def self.dispatch(method, params)
      raise 'Invalid parameters' unless params.is_a?(Hash)
      case method
      when 'status' then status
      when 'get_request' then request_info
      when 'read_reference' then read_reference(params['reference_id'])
      when 'create_table' then create_table(params)
      when 'create_job' then create_job(params)
      when 'get_job' then job_summary(find_job(params['job_id']).first,params.fetch('include_parts',false))
      when 'apply_parts' then apply_parts(params)
      when 'capture_job' then capture_job(params)
      when 'request_review' then request_review(params)
      when 'finish_model' then finish_model(params)
      when 'inspect_models' then {models:generated.map { |instance| inspect_instance(instance) }}
      else raise 'Unknown FurniForge method'
      end
    end

    def self.current_request
      # In-memory requests are scoped to the active model, not reused in another model.
      @requests ||= {}
      @requests[Sketchup.active_model.object_id] ||= restore_draft(Sketchup.active_model)
    end

    # Check the actual local listener from another thread; never call SketchUp API from this thread.
    def self.check_bridge_connection
      return {state:'disconnected',message:'SketchUp bridge is stopped.'} unless @server && @token
      now=Time.now
      if (!@health_probe_at || now-@health_probe_at>=5) && !(@health_thread && @health_thread.alive?)
        @health_probe_at=now
        port=@server.addr[1];token=@token
        @health_thread=Thread.new do
          sock=nil
          begin
            require 'timeout'
            response=Timeout.timeout(4) do
              sock=TCPSocket.new('127.0.0.1',port)
              sock.write(JSON.generate({id:'health',token:token,method:'status',params:{},client:{name:'FurniForge health check',health_probe:true}})+"\n")
              JSON.parse(sock.gets.to_s)
            end
            @health_result={state:(response['id']=='health' && response['ok'] ? 'connected' : 'disconnected'),checked_at:Time.now.utc.iso8601}
          rescue
            @health_result={state:'disconnected',checked_at:Time.now.utc.iso8601}
          ensure
            sock.close if sock
          end
        end
      end
      return {state:'checking'} unless @health_result
      return {state:'checking'} if now-@health_probe_at>10
      @health_result
    end

    def self.status
      m = Sketchup.active_model
      {version:VERSION,sketchup:Sketchup.version,bridge_running:!@server.nil?,model:m.title,
       top_level_entities:m.entities.length,editing_component:!m.active_path.nil?,
       last_mcp_caller:@last_caller,last_mcp_call_at:@last_seen&.utc&.iso8601,
       assistant_connection:'Last caller is informational; no persistent assistant connection is claimed.',
       background_mcp_seen:(@background_seen_request_id==request_info[:request_id]),background_mcp_seen_at:(@background_seen_request_id==request_info[:request_id] ? @background_seen_at&.utc&.iso8601 : nil),
       supported_models:['image_based_custom_model'],last_error:@last_error}
    end

    def self.request_info
      req = current_request
      req[:request_id] ||= SecureRandom.uuid
      required = %w[width_mm depth_mm height_mm]
      {request_id:req[:request_id],generation:req[:generation],values:req[:values],source:req[:values].transform_values { 'manual' },
       missing_required:req[:references].empty? ? ['reference_image'] : [],
       optional_missing_dimensions:required.reject { |key| req[:values].key?(key) },
       references:req[:references].map { |r| {id:r[:id],name:r[:name]} },
       draft_missing_references:req[:draft_missing_references] || 0,
       optional_blank_fields_do_not_require_analysis:true,
       analysis_provider:'selected_assistant',model_type:'image_based',
       workflow:'reference image -> optional details -> model in SketchUp',
       usage_note:'Provided values are not re-estimated. Shape interpretation, geometry planning and visual review may still use the assistant.',
       jobs:job_roots.map { |r| {id:r.get_attribute(JOB_DICT,'id'),name:r.name} }}
    end

    def self.save_request(data)
      raise 'Invalid request' unless data.is_a?(Hash)
      values = {}
      %w[name category description material notes assistant].each do |key|
        value = data[key].to_s.strip
        raise 'Text field is too long' if value.length > 4000
        values[key] = value unless value.empty?
      end
      { 'width_mm'=>[1,20000], 'depth_mm'=>[1,20000], 'height_mm'=>[1,20000] }.each do |key,range|
        next if data[key].nil? || data[key].to_s.strip.empty?
        number = Float(data[key])
        raise "Invalid #{key}" unless number.finite? && number.between?(*range)
        values[key] = number
      end
      if current_request[:values] != values
        current_request[:request_id]=SecureRandom.uuid
        current_request[:generation]=nil
      end
      current_request[:values] = values
      request_info
    end

    def self.prepare_model_request(values)
      raise 'Attach at least one reference image first.' if current_request[:references].empty?
      save_request(values)
      current_request[:request_id]=SecureRandom.uuid
      current_request[:read_reference_ids]=[]
      current_request[:generation]={status:'waiting_for_assistant'}
      current_request[:active_job]=nil
      @last_preview=nil
      request_info
    end

    def self.add_reference
      file = UI.openpanel('Choose a reference image', '', 'Images|*.png;*.jpg;*.jpeg||')
      return unless file
      ext = File.extname(file).downcase
      raise 'Only PNG and JPEG are supported' unless %w[.png .jpg .jpeg].include?(ext)
      raise 'Image must be 5 MB or smaller' if File.size(file) > 5 * 1024 * 1024
      raise 'Maximum 8 reference images' if current_request[:references].length >= 8
      current_request[:references] << {id:SecureRandom.uuid,name:File.basename(file),path:file}
      current_request[:request_id]=SecureRandom.uuid
      current_request[:generation]=nil
    end

    def self.read_reference(id)
      ref = current_request[:references].find { |r| r[:id] == id }
      raise 'Reference was not attached in the panel' unless ref
      bytes = File.binread(ref[:path], 5 * 1024 * 1024 + 1)
      raise 'Image exceeds 5 MB' if bytes.bytesize > 5 * 1024 * 1024
      mime = if bytes.start_with?("\x89PNG\r\n\x1a\n".b)
        'image/png'
      elsif bytes.start_with?("\xff\xd8\xff".b)
        'image/jpeg'
      else
        raise 'Invalid image data'
      end
      current_request[:read_reference_ids] ||= []
      current_request[:read_reference_ids] |= [id]
      {mimeType:mime,data:Base64.strict_encode64(bytes)}
    end

    def self.generated
      Sketchup.active_model.entities.grep(Sketchup::ComponentInstance).select { |i| i.get_attribute(DICT,'operation_id') }
    end

    def self.inspect_instance(i)
      b = i.bounds
      parts = i.definition.entities.grep(Sketchup::Group)
      {entity_id:i.persistent_id,name:i.name,operation_id:i.get_attribute(DICT,'operation_id'),
       dimensions_mm:{width:b.width.to_mm.round(4),depth:b.height.to_mm.round(4),height:b.depth.to_mm.round(4)},
       part_count:parts.length,all_parts_solid:parts.all?(&:manifold?),
       parameters:JSON.parse(i.get_attribute(DICT,'parameters','{}'))}
    end

    def self.create_table(params)
      model = Sketchup.active_model
      raise 'Exit component editing before generating a model' if model.active_path
      operation_id = params['operation_id'].to_s
      raise 'Invalid operation ID' unless operation_id.match?(/\A[a-zA-Z0-9_-]{8,80}\z/)
      existing = generated.find { |i| i.get_attribute(DICT,'operation_id') == operation_id }
      return inspect_instance(existing).merge(already_created:true) if existing
      values = current_request[:values]
      dims = {}
      {'width_mm'=>[200,5000],'depth_mm'=>[200,3000],'height_mm'=>[200,1500]}.each do |key,range|
        if values.key?(key) && params.key?(key) && Float(params[key]) != values[key]
          raise "Manual #{key} is locked; change it in the panel before generating."
        end
        number = Float(values.fetch(key) { params.fetch(key) { raise "Missing confirmed dimension: #{key}" } })
        raise "Invalid #{key}" unless number.finite? && number.between?(*range)
        dims[key] = number
      end
      {'top_thickness_mm'=>[30,10,100],'leg_size_mm'=>[50,15,150],'leg_inset_mm'=>[40,0,300]}.each do |key,(default,min,max)|
        number = Float(params.fetch(key,default))
        raise "Invalid #{key}" unless number.finite? && number.between?(min,max)
        dims[key] = number
      end
      w,d,h,t,l,inset = %w[width_mm depth_mm height_mm top_thickness_mm leg_size_mm leg_inset_mm].map { |key| dims[key].mm }
      raise 'Legs would overlap or extend outside the tabletop' unless 2*(inset+l) < [w,d].min
      raise 'Tabletop is taller than the table' unless t < h
      # Place beside existing top-level drawing bounds, preserving all existing objects.
      bounds = model.bounds
      origin = bounds.empty? ? [0,0,0] : [bounds.max.x + 500.mm, bounds.min.y, 0]
      model.start_operation('FurniForge: Create table', true)
      begin
        definition = model.definitions.add("FurniForge Table #{operation_id}")
        box(definition.entities,'Tabletop',[0,0,h-t],w,d,t)
        [[inset,inset],[w-inset-l,inset],[inset,d-inset-l],[w-inset-l,d-inset-l]].each_with_index do |(x,y),index|
          box(definition.entities,"Leg #{index+1}",[x,y,0],l,l,h-t)
        end
        instance = model.entities.add_instance(definition,Geom::Transformation.translation(origin))
        instance.name = values.fetch('name','FurniForge Table')
        instance.set_attribute(DICT,'operation_id',operation_id)
        instance.set_attribute(DICT,'parameters',JSON.generate(dims))
        instance.set_attribute(DICT,'manual_request',JSON.generate(values))
        instance.set_attribute(DICT,'owner','yviero_m')
        model.commit_operation
        inspect_instance(instance).merge(already_created:false)
      rescue
        model.abort_operation
        raise
      end
    end

    def self.box(entities, name, origin, w, d, h)
      group = entities.add_group
      group.name = name
      face = group.entities.add_face([0,0,0],[w,0,0],[w,d,0],[0,d,0])
      face.reverse! if face.normal.z < 0
      face.pushpull(h)
      group.transform!(Geom::Transformation.translation(origin))
      group
    end

    require_relative 'draft'
    require_relative 'workflow'
    require_relative 'background'
    require_relative 'workspace_ui'

    unless file_loaded?(__FILE__)
      menu = UI.menu('Extensions').add_submenu('FurniForge')
      menu.add_item('Open workspace') { show_panel }
      menu.add_item('Start bridge') { start; show_panel }
      menu.add_item('Stop bridge') { stop; push_panel('Bridge stopped.') }
      file_loaded(__FILE__)
      begin
        start
      rescue => e
        UI.messagebox("FurniForge bridge could not start: #{e.message}")
      end
    end
  end
end

