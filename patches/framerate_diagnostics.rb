# Copyright 2019 DragonRuby LLC
# MIT License
# framerate_diagnostics.rb has been released under MIT (*only this file*).

module GTK
  class Runtime
    # @visibility private
    module FramerateDiagnostics
      def framerate_get_diagnostics
        <<-S
* INFO: Framerate Diagnostics

#{$perf_counter_outputs_push_count} draw calls!
#{$perf_counter_primitive_is_array} array primitives!

PRIMITIVE   COUNT, STATIC COUNT
solids:     #{@args.outputs.solids.length}, #{@args.outputs.static_solids.length}
sprites:    #{@args.outputs.sprites.length}, #{@args.outputs.static_sprites.length}
primitives: #{@args.outputs.primitives.length}, #{@args.outputs.static_primitives.length}
labels:     #{@args.outputs.labels.length}, #{@args.outputs.static_labels.length}
lines:      #{@args.outputs.lines.length}, #{@args.outputs.static_lines.length}
borders:    #{@args.outputs.borders.length}, #{@args.outputs.static_borders.length}
debug:      #{@args.outputs.debug.length}, #{@args.outputs.static_debug.length}
reserved:   #{@args.outputs.reserved.length}, #{@args.outputs.static_reserved.length}
        S

      end

      def framerate_warning_message
        <<-S
* WARNING:
Your average framerate dropped below 60 fps for two seconds.
The average FPS was #{current_framerate}.
#{framerate_get_diagnostics}
        S

      end

      def current_framerate_primitives
        framerate_diagnostics_primitives
      end

      def framerate_diagnostics_primitives
        lines = []
        lines.push("solids:     #{@args.outputs.solids.length}, #{@args.outputs.static_solids.length}") unless @args.outputs.solids.length + @args.outputs.static_solids.length == 0
        lines.push("sprites:    #{@args.outputs.sprites.length}, #{@args.outputs.static_sprites.length}") unless @args.outputs.sprites.length + @args.outputs.static_sprites.length == 0
        lines.push("primitives: #{@args.outputs.primitives.length}, #{@args.outputs.static_primitives.length}") unless @args.outputs.primitives.length + @args.outputs.static_primitives.length == 0
        lines.push("labels:     #{@args.outputs.labels.length}, #{@args.outputs.static_labels.length}") unless @args.outputs.labels.length + @args.outputs.static_labels.length == 0
        lines.push("lines:      #{@args.outputs.lines.length}, #{@args.outputs.static_lines.length}") unless @args.outputs.lines.length + @args.outputs.static_lines.length == 0
        lines.push("borders:    #{@args.outputs.borders.length}, #{@args.outputs.static_borders.length}") unless @args.outputs.borders.length + @args.outputs.static_borders.length == 0
        lines.push("debug:      #{@args.outputs.debug.length}, #{@args.outputs.static_debug.length}") unless @args.outputs.debug.length + @args.outputs.static_debug.length == 0
        lines.push("reserved:   #{@args.outputs.reserved.length}, #{@args.outputs.static_reserved.length}") unless @args.outputs.reserved.length + @args.outputs.static_reserved.length == 0
        out = [
            {
                x:         5,
                y:         5.from_top,
                text:      "FPS: %.2f" % args.gtk.current_framerate,
                r:         255,
                g:         0,
                b:         0,
                size_enum: -2
            }.label,
            {
                x:         5,
                y:         20.from_top,
                text:      "Draw Calls: #{$perf_counter_outputs_push_count}",
                r:         255,
                g:         0,
                b:         0,
                size_enum: -2
            }.label,
            {
                x:         5,
                y:         35.from_top,
                text:      "Array Primitives: #{$perf_counter_primitive_is_array}",
                r:         255,
                g:         0,
                b:         0,
                size_enum: -2
            }.label,
            {
                x:         5,
                y:         50.from_top,
                text:      "Mouse: #{@args.inputs.mouse.point}",
                r:         255,
                g:         0,
                b:         0,
                size_enum: -2
            }.label,
        ]
        lines.each do |line|
          out.push({
                       x:         5,
                       y:         out[-1].y - 15,
                       text:      line,
                       r:         255,
                       g:         0,
                       b:         0,
                       size_enum: -2
                   }.label)
        end
        out
      end

    end
  end
end
