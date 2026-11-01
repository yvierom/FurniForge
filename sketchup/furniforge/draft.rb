# Copyright (c) 2026 Yuan Viero Mahendra. All rights reserved.
# Draft metadata is saved in the SketchUp model; image bytes stay in the local cache.
module YvieroM
  module FurniForge
    def self.draft_cache_dir
      File.join(File.dirname(state_path), 'references')
    end

    def self.restore_draft(model)
      request={values:{},references:[],request_id:SecureRandom.uuid,read_reference_ids:[]}
      raw=model.get_attribute(DICT,'draft_v1')
      return request unless raw.is_a?(String) && raw.bytesize <= 100_000
      data=JSON.parse(raw)
      return request unless data.is_a?(Hash) && data['version']==1 && data['values'].is_a?(Hash) && data['references'].is_a?(Array)
      text_keys=%w[name category description material notes assistant codex_model codex_effort]
      dimension_keys=%w[width_mm depth_mm height_mm]
      request[:values]=data['values'].select do |k,v|
        (text_keys.include?(k) && v.is_a?(String) && v.length<=4000) ||
          (dimension_keys.include?(k) && v.is_a?(Numeric) && v.finite? && v.between?(1,20000))
      end
      request[:draft_missing_references]=0
      data['references'].first(8).each do |r|
        next unless r.is_a?(Hash) && r['id'].is_a?(String) && r['id'].match?(/\A[a-f0-9-]{36}\z/) && %w[.png .jpg].include?(r['ext']) && r['name'].is_a?(String)
        path=File.join(draft_cache_dir,r['id']+r['ext'])
        if File.file?(path)
          request[:references] << {id:r['id'],name:r['name'][0,180],path:path}
        else
          request[:draft_missing_references]+=1
        end
      end
      request
    rescue JSON::ParserError, TypeError
      request
    end

    def self.persist_draft(model)
      raise 'Stop the current session before saving the draft.' if background_active?
      FileUtils.mkdir_p(draft_cache_dir)
      references=current_request[:references].map do |ref|
        bytes=File.binread(ref[:path],5*1024*1024+1)
        raise 'Reference exceeds 5 MB; attach it again.' if bytes.bytesize>5*1024*1024
        ext=if bytes.start_with?("\x89PNG\r\n\x1a\n".b); '.png'
            elsif bytes.start_with?("\xff\xd8\xff".b); '.jpg'
            else; raise 'Reference is not a valid PNG or JPEG.'; end
        id=ref[:id].to_s
        raise 'Invalid reference ID; attach the image again.' unless id.match?(/\A[a-f0-9-]{36}\z/)
        path=File.join(draft_cache_dir,id+ext)
        File.binwrite(path,bytes) unless File.expand_path(ref[:path])==File.expand_path(path)
        {id:id,name:ref[:name].to_s[0,180],ext:ext}
      end
      data={version:1,values:current_request[:values],references:references}
      model.start_operation('FurniForge: Save draft',true)
      begin
        model.set_attribute(DICT,'draft_v1',JSON.generate(data))
        model.commit_operation
      rescue
        model.abort_operation
        raise
      end
      current_request[:draft_missing_references]=0
    end
  end
end
