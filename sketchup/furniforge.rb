# Copyright (c) 2026 yviero_m. All rights reserved.
require 'sketchup.rb'
require 'extensions.rb'
module YvieroM
  module FurniForge
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('FurniForge', 'furniforge/main')
      extension.description = 'Local MCP bridge and editable furniture prototypes.'
      extension.version = '0.4.2'
      extension.creator = 'yviero_m'
      extension.copyright = '2026 yviero_m. All rights reserved.'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end

