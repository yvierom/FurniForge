# Copyright (c) 2026 yviero_m.
require 'win32ole' if Sketchup.platform==:platform_win
module YvieroM
 module FurniForge
  def self.launcher_config
   path=File.join(File.dirname(state_path),'launcher.json')
   raise 'Background Codex is not configured. See Setup guide.' unless File.file?(path)
   config=JSON.parse(File.read(path,encoding:'bom|utf-8'))
   %w[node codex server].each { |key| raise "Launcher #{key} path is unavailable" unless config[key].is_a?(String) && File.file?(config[key]) }
   config
  end
  def self.runner_state
   run=current_request[:runner]
   return {status:'idle'} unless run
   begin
    result=JSON.parse(File.read(run[:status_file]))
    if result['status']=='starting' && Time.now-run[:started_at]>60
     result['status']='failed';result['message']='Codex did not start within 60 seconds. Check launcher paths and account sign-in.'
    end
    run[:last_status]=result
    result
   rescue
    run[:last_status] || {status:'starting',message:'Starting background session…'}
   end
  end
  def self.launcher_info
   config=launcher_config
   {available:true,provider:'GPT Codex',run:runner_state}
  rescue => e
   {available:false,provider:'GPT Codex',message:e.message,run:runner_state}
  end
  def self.background_active?
   %w[starting running waiting_approval].include?((runner_state['status'] || runner_state[:status]).to_s)
  end
  def self.start_background
   raise 'Background launch is currently available for GPT Codex. Choose Codex to use automatic generation.' unless current_request[:values]['assistant']=='GPT Codex'
   config=launcher_config
   raise 'A background session is already running.' if background_active?
   request_id=request_info[:request_id]
   folder=File.join(File.dirname(state_path),'runs',request_id)
   FileUtils.mkdir_p(folder)
   task={node:config['node'],codex:config['codex'],server:config['server'],bridge_state:state_path,
    request_id:request_id,cwd:File.join(folder,'workspace'),status_file:File.join(folder,'status.json'),cancel_file:File.join(folder,'cancel'),approval_file:File.join(folder,'approval.json')}
   file=File.join(folder,'task.json');File.write(file,JSON.generate(task))
   File.write(task[:status_file],JSON.generate({status:'starting',message:'Starting Codex…'}))
   script=File.join(__dir__,'runner','codex-runner.mjs')
   paths=[config['node'],script,file]
   raise 'Invalid launcher path' if paths.any? { |p| p.match?(/["\r\n]/) }
   command=paths.map { |p| '"'+p.tr('/','\\')+'"' }.join(' ')
   # Window style 0 launches the Node supervisor without a visible console.
   WIN32OLE.new('WScript.Shell').Run(command,0,false)
   current_request[:runner]={status_file:task[:status_file],cancel_file:task[:cancel_file],approval_file:task[:approval_file],started_at:Time.now}
   current_request[:generation]={status:'running'}
  end
  def self.respond_background_approval(token,action)
   run=current_request[:runner];state=runner_state
   raise 'No approval request is waiting.' unless run && state['status']=='waiting_approval' && state.dig('approval','token')==token
   raise 'Invalid approval decision.' unless %w[accept decline].include?(action)
   path=run[:approval_file];temp=path+'.tmp'
   File.write(temp,JSON.generate({token:token,action:action}))
   File.rename(temp,path)
  end
  def self.cancel_background
   run=current_request[:runner]
   if run && background_active?
    File.write(run[:cancel_file],'cancel')
    current_request[:request_id]=SecureRandom.uuid # Revoke the old session immediately, before process shutdown.
   end
  end
  def self.add_uploaded_references(items)
   raise 'Choose 1..8 images.' unless items.is_a?(Array) && items.length.between?(1,8)
   raise 'Maximum 8 reference images.' if current_request[:references].length+items.length>8
   raise 'Stop the current session before changing images.' if background_active?
   decoded=items.map do |item|
    raise 'Invalid image input' unless item.is_a?(Hash) && item['data'].is_a?(String) && item['data'].bytesize<=7*1024*1024
    header,encoded=item['data'].split(',',2)
    raise 'Only PNG and JPEG are supported.' unless ['data:image/png;base64','data:image/jpeg;base64'].include?(header)
    bytes=Base64.strict_decode64(encoded.to_s)
    raise 'Image must be 5 MB or smaller.' if bytes.bytesize>5*1024*1024
    png=bytes.start_with?("\x89PNG\r\n\x1a\n".b);jpeg=bytes.start_with?("\xff\xd8\xff".b)
    raise 'Invalid image data.' unless (png && header.include?('png')) || (jpeg && header.include?('jpeg'))
    [File.basename(item['name'].to_s)[0,180],bytes,png ? '.png' : '.jpg']
   end
   folder=File.join(File.dirname(state_path),'references');FileUtils.mkdir_p(folder)
   added=[]
   begin
    decoded.each do |name,bytes,ext|
     id=SecureRandom.uuid;path=File.join(folder,id+ext);File.binwrite(path,bytes)
     added<<{id:id,name:name,path:path}
    end
   rescue
    added.each { |r| File.delete(r[:path]) if File.file?(r[:path]) };raise
   end
   current_request[:references].concat(added)
   current_request[:request_id]=SecureRandom.uuid;current_request[:generation]=nil
   added.length
  end
 end
end
