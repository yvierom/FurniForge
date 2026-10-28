# Isolated draft regression test. Run in SketchUp Ruby or a Ruby 2.7+ environment.
# Uses a fake model and a temporary cache; never touches the active SketchUp model.
require 'tmpdir'
require 'fileutils'
require 'json'
require 'securerandom'

source_path=File.expand_path('../sketchup/furniforge/draft.rb', __dir__)
source=File.read(source_path, encoding:'UTF-8').sub('module YvieroM','module FFIsolatedDraftTest')
eval(source, TOPLEVEL_BINDING, source_path)
f=FFIsolatedDraftTest::FurniForge
f.const_set(:DICT,'furniforge-test-draft')
model_class=Class.new do
  def initialize; @data={}; end
  def get_attribute(dict,key); @data[[dict,key]]; end
  def set_attribute(dict,key,value); @data[[dict,key]]=value; end
  def start_operation(*); end
  def commit_operation; end
  def abort_operation; end
end
checks=[]
Dir.mktmpdir('ff-draft-check-') do |dir|
  f.define_singleton_method(:state_path) { File.join(dir,'bridge.json') }
  f.define_singleton_method(:background_active?) { false }
  path=File.join(dir,'source.png')
  File.binwrite(path, "\x89PNG\r\n\x1a\n".b + 'test')
  request={values:{'description'=>'Draft test','width_mm'=>1200.0},references:[{id:SecureRandom.uuid,name:'reference.png',path:path}],request_id:SecureRandom.uuid,read_reference_ids:[]}
  f.define_singleton_method(:current_request) { request }
  model=model_class.new
  f.persist_draft(model)
  restored=f.restore_draft(model)
  raise 'Values not restored' unless restored[:values]['description']=='Draft test' && restored[:values]['width_mm']==1200.0
  raise 'Image not restored' unless restored[:references].length==1 && File.file?(restored[:references][0][:path])
  raise 'Old request id reused' if restored[:request_id]==request[:request_id]
  checks << 'values and reference restored with new request id'
  File.delete(restored[:references][0][:path])
  missing=f.restore_draft(model)
  raise 'Missing image not reported' unless missing[:draft_missing_references]==1 && missing[:references].empty?
  checks << 'missing reference reported'
  model.set_attribute(f::DICT,'draft_v1','{bad json')
  raise 'Invalid data did not fall back safely' unless f.restore_draft(model)[:references].empty?
  checks << 'invalid draft safely ignored'
end
puts "Draft regression: #{checks.join('; ')}"
