require 'json'
require 'tmpdir'
require 'fileutils'
root=File.expand_path('..',__dir__)
source=File.read(File.join(root,'sketchup/furniforge/background.rb'))
method=source[/  def self\.launcher_config\n.*?\n  end\n/m] or raise 'Could not extract launcher method'
results=[]
Dir.mktmpdir('ff-launcher-') do |dir|
  sandbox=Module.new
  sandbox.const_set(:ENV,{'LOCALAPPDATA'=>dir})
  sandbox.define_singleton_method(:state_path){File.join(dir,'bridge.json')}
  sandbox.module_eval(method)
  app=File.join(dir,'OpenAI','Codex','bin')
  node=File.join(dir,'node.exe');server=File.join(dir,'server.mjs')
  File.write(node,'');File.write(server,'')
  stale=File.join(app,'old','codex.exe')
  config=File.join(dir,'launcher.json')
  write_config=->(codex){File.write(config,JSON.generate({node:node,server:server,codex:codex}))}
  v1=File.join(app,'new','codex.exe');FileUtils.mkdir_p(File.dirname(v1));File.write(v1,'')
  write_config.call(stale);raise 'Recovery failed' unless File.identical?(sandbox.launcher_config['codex'],v1);results << 'stale recovered'
  custom=File.join(dir,'custom.exe');File.write(custom,'');write_config.call(custom);raise 'Custom changed' unless sandbox.launcher_config['codex']==custom;results << 'valid custom preserved'
  v2=File.join(app,'other','codex.exe');FileUtils.mkdir_p(File.dirname(v2));File.write(v2,'');write_config.call(stale)
  begin;sandbox.launcher_config;raise 'Ambiguous recovery accepted';rescue RuntimeError=>e;raise unless e.message.include?('Run setup-launcher.ps1');end;results << 'ambiguous rejected'
  write_config.call(File.join(dir,'missing-custom.exe'))
  begin;sandbox.launcher_config;raise 'Missing custom accepted';rescue RuntimeError=>e;raise unless e.message.include?('Run setup-launcher.ps1');end;results << 'missing custom rejected'
end
puts results.join('; ')
