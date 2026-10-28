# Copyright (c) 2026 yviero_m. All rights reserved.
module YvieroM
  module FurniForge
    def self.panel_state
      id=current_request[:active_job]
      job=nil
      begin
        job=job_summary(find_job(id).first) if id
      rescue
        current_request[:active_job]=nil
      end
      preview=nil
      if @last_preview && job && @last_preview['job_id']==id && @last_preview['revision']==job['revision']
        preview=@last_preview['data']
      end
      {status:status,bridge_connection:check_bridge_connection,launcher:launcher_info,request:request_info,job:job,preview:preview,model_id:Sketchup.active_model.object_id}
    end
    def self.push_panel(message=nil)
      return unless @dialog && @dialog.visible?
      @dialog.execute_script("window.receiveState(#{JSON.generate(panel_state)},#{JSON.generate(message)})")
    end
    def self.show_panel
      if @dialog && @dialog.visible?
        @dialog.bring_to_front
        return
      end
      @dialog=UI::HtmlDialog.new(dialog_title:'FurniForge · yviero_m',preferences_key:'yviero_m.furniforge.v2',
        scrollable:true,resizable:true,width:1240,height:850,style:UI::HtmlDialog::STYLE_DIALOG)
      @dialog.set_file(File.join(__dir__,'ui','panel.html'))
      @dialog.add_action_callback('ready') { |_ctx| push_panel }
      @dialog.add_action_callback('refresh') { |_ctx| push_panel }
      @dialog.add_action_callback('workspace_action') do |_ctx,json|
        begin
          command=JSON.parse(json)
          if command['model_id'] && command['model_id']!=Sketchup.active_model.object_id
            raise 'Active SketchUp model changed. Refresh the workspace before continuing.'
          end
          case command['action']
          when 'generate'
            raise 'A background session is already running.' if background_active?
            raise 'Choose GPT Codex for background generation.' unless command.dig('values','assistant')=='GPT Codex'
            raise 'Allow the background session before starting.' unless command['allow_background']==true
            launcher_config
            prepare_model_request(command['values'])
            start_background
            push_panel('Codex is starting in the background. No copy and paste needed.')
          when 'respond_approval'
            respond_background_approval(command['token'],command['decision'])
            push_panel('Decision sent to Codex. Waiting for the session to continue…')
          when 'cancel_background'
            cancel_background
            id=current_request[:active_job]
            control_job('stop') if id && !%w[completed accepted stopped].include?(find_job(id)[1]['stage'])
            push_panel('Stopping the background session…')
          when 'upload_references'
            count=add_uploaded_references(command['images'])
            push_panel("#{count} reference images added.")
          when 'remove_reference'
            raise 'Stop the current session before changing images.' if background_active?
            current_request[:references].reject! { |r| r[:id]==command['reference_id'] }
            current_request[:request_id]=SecureRandom.uuid
            current_request[:generation]=nil
            push_panel('Reference removed.')
          when 'save'
            raise 'Stop the current session before changing details.' if background_active?
            save_request(command['values'])
            push_panel('Brief saved. Provided values will not be re-estimated.')
          when 'reference'
            add_reference
            push_panel('Reference attached locally. Only an explicit assistant tool call sends it to the assistant.')
          when 'select_job'
            find_job(command['job_id'])
            current_request[:active_job]=command['job_id']
            @last_preview=nil
            push_panel
          when 'stop','accept','revise'
            control_job(command['action'],command['feedback'].to_s)
          when 'restore'
            restore_job
          when 'preview'
            capture_job({'job_id'=>current_request[:active_job],'view'=>command.fetch('view','perspective')})
          when 'export'
            export_job
          else raise 'Unknown workspace action'
          end
        rescue => e
          push_panel("Error: #{e.message}")
        end
      end
      @dialog.show
      @dialog.center
    end
  end
end

