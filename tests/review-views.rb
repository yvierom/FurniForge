# Run with Ruby, or load from SketchUp's Ruby console. No SketchUp model changes.
source=File.read(File.expand_path('../sketchup/furniforge/workflow.rb',__dir__))
method=source[/    def self\.missing_final_review_views\(job\)\n.*?\n    end\n/m] or raise 'Review policy not found'
policy=Module.new
policy.module_eval(method)
job={'revision'=>2,'previews'=>{}}
raise 'All views required' unless policy.missing_final_review_views(job)==%w[perspective front bottom]
job['previews']={'perspective'=>{'revision'=>2},'front'=>{'revision'=>1},'bottom'=>{'revision'=>2}}
raise 'Stale front preview accepted' unless policy.missing_final_review_views(job)==['front']
job['previews']['front']={'revision'=>2}
raise 'Current views rejected' unless policy.missing_final_review_views(job).empty?
job['revision']=3
raise 'Old previews accepted after geometry changes' unless policy.missing_final_review_views(job)==%w[perspective front bottom]
puts 'Final review view and revision checks passed'
