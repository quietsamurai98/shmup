# Copyright 2019 DragonRuby LLC
# MIT License
# console.rb has been released under MIT (*only this file*).

# Contributors outside of DragonRuby who also hold Copyright:
# - Kevin Fischer: https://github.com/kfischer-okarin

module GTK
  class Console
    def console_toggle_keys
      [
          :backtick!,
          :tilde!
      ]
    end

    def mouse_wheel_scroll args
      @inertia ||= 0

      if args.inputs.mouse.wheel && args.inputs.mouse.wheel.y > 0
        @inertia = -1
      elsif args.inputs.mouse.wheel && args.inputs.mouse.wheel.y < 0
        @inertia = 1
      end

      if args.inputs.mouse.click
        @inertia = 0
      end

      return if @inertia == 0

      if @inertia != 0
        @inertia = (@inertia * 0.7)
        if @inertia > 0
          @log_offset -= 1
        elsif @inertia < 0
          @log_offset += 1
        end
      end

      if @inertia.abs < 0.01
        @inertia = 0
      end

      if @log_offset > @log.size
        @log_offset = @log.size
      elsif @log_offset < 0
        @log_offset = 0
      end
    end
  end
end
