require 'fastlane_core'

FastlaneCore::UI.message "----------------------------------------------------"
FastlaneCore::UI.message "--- LOADING CUSTOM FRAMEIT PATCH FOR OUTLINE ---"
FastlaneCore::UI.message "----------------------------------------------------"

# Try to load frameit to ensure we patch the real thing or at least have the module available
begin
  require 'frameit'
  FastlaneCore::UI.message "--- Successfully required 'frameit' ---"
rescue LoadError
  FastlaneCore::UI.message "--- Could not require 'frameit', relying on Fastlane lazy loading or internal paths ---"
end

module FrameitTextOutlinePatch
  def build_text_images(max_width, max_height)
    FastlaneCore::UI.message "--- Executing patched build_text_images (via prepend) ---"
    
    words = [:keyword, :title].keep_if { |a| fetch_text(a) } # optional keyword/title
    FastlaneCore::UI.message "--- Found words to render: #{words} ---"
    
    results = {}
    trim_boxes = {}
    top_vertical_trim_offset = Float::INFINITY 
    bottom_vertical_trim_offset = 0

    words.each do |key|
      # Create empty background
      # We need to find where Frameit::ROOT is. If frameit wasn't required, this might fail.
      # Fallback to a safe check?
      root_path = defined?(Frameit::ROOT) ? Frameit::ROOT : "." 
      empty_path = File.join(root_path, "lib/assets/empty.png")
      
      # If the file doesn't exist (because we are patching via fastlane gem path structure),
      # we might need to find it differently.
      # But usually Frameit::ROOT is set when frameit is loaded.
      
      # If frameit is not loaded yet, we can't rely on Frameit::ROOT.
      # However, we are prepending, so this method runs when frameit IS loaded.
      
      text_image = MiniMagick::Image.open(empty_path)
      image_height = max_height 
      text_image.combine_options do |i|
        i.resize("#{max_width * 5.0}x#{image_height}!") 
      end

      current_font = font(key)
      text = fetch_text(key)
      FastlaneCore::UI.verbose("Using #{current_font} as font the #{key} of #{screenshot.path}") if current_font
      FastlaneCore::UI.verbose("Adding text '#{text}'")
      
      text.gsub!('\n', "\n")
      text.gsub!(/(?<!\\)(')/) { |s| "\\#{s}" } 

      interline_spacing = @config['interline_spacing']

      text_image.combine_options do |i|
        i.font(current_font) if current_font
        i.weight(@config[key.to_s]['font_weight']) if @config[key.to_s]['font_weight']
        i.gravity("Center")
        
        # Calculate point size with optional multiplier
        point_size = actual_font_size(key)
        multiplier = @config[key.to_s]['font_scale_multiplier']
        point_size *= multiplier if multiplier
        
        i.pointsize(point_size)
        i.interline_spacing(interline_spacing) if interline_spacing
        
        # 1. Draw Stroke (Background)
        if @config[key.to_s]['stroke_color']
            FastlaneCore::UI.message "--- Drawing stroke for #{key} ---"
            i.stroke(@config[key.to_s]['stroke_color'])
            i.strokewidth(@config[key.to_s]['stroke_width'] || 5)
            i.draw("text 0,0 '#{text}'")
        end
        
        # 2. Draw Fill (Foreground)
        i.stroke('none')
        i.fill(@config[key.to_s]['color'])
        i.draw("text 0,0 '#{text}'")
      end

      results[key] = text_image

      # Recalculate trim box (same logic as original)
      calculated_trim_box = text_image.identify do |b|
        b.format("%@") 
      end

      trim_box = Frameit::Trimbox.new(calculated_trim_box)

      if trim_box.offset_y < top_vertical_trim_offset
        top_vertical_trim_offset = trim_box.offset_y
      end

      if (trim_box.offset_y + trim_box.height) > bottom_vertical_trim_offset
        bottom_vertical_trim_offset = trim_box.offset_y + trim_box.height
      end

      trim_boxes[key] = trim_box
    end

    # Crop text images (same logic as original)
    words.each do |key|
      trim_box = trim_boxes[key]

      if trim_box.offset_y > top_vertical_trim_offset
        trim_box.height += trim_box.offset_y - top_vertical_trim_offset
        trim_box.offset_y = top_vertical_trim_offset
      end

      if (trim_box.offset_y + trim_box.height) < bottom_vertical_trim_offset
        trim_box.height = bottom_vertical_trim_offset - trim_box.offset_y
      end

      results[key].crop(trim_box.string_format)
    end

    results
  end
end

if defined?(Frameit::Editor)
  FastlaneCore::UI.message "--- Frameit::Editor is defined. Prepending patch... ---"
  Frameit::Editor.prepend(FrameitTextOutlinePatch)
  FastlaneCore::UI.message "--- Patch prepended successfully ---"
else
  FastlaneCore::UI.message "--- Frameit::Editor is NOT defined yet. Waiting for it... ---"
  # Define stub to allow prepend, assuming real class re-opens it later
  module Frameit
    class Editor
    end
  end
  Frameit::Editor.prepend(FrameitTextOutlinePatch)
  FastlaneCore::UI.message "--- Defined Frameit::Editor stub and prepended patch ---"
end