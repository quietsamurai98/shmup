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

    def process_inputs args
      if console_toggle_key_down? args
        args.inputs.text.clear
        toggle
      end

      return unless visible?

      args.inputs.text.each { |str| prompt << str }
      args.inputs.text.clear
      mouse_wheel_scroll args

      @log_offset = 0 if @log_offset < 0

      if args.inputs.keyboard.key_down.enter
        eval_the_set_command
      elsif args.inputs.keyboard.key_down.v
        if args.inputs.keyboard.key_down.control || args.inputs.keyboard.key_down.meta
          prompt << $gtk.ffi_misc.getclipboard
        end
      elsif args.inputs.keyboard.key_down.up
        if @command_history_index == -1
          @nonhistory_input = current_input_str
        end
        if @command_history_index < (@command_history.length - 1)
          @command_history_index += 1
          self.current_input_str = @command_history[@command_history_index].dup
        end
      elsif args.inputs.keyboard.key_down.down
        if @command_history_index == 0
          @command_history_index = -1
          self.current_input_str = @nonhistory_input
          @nonhistory_input      = ''
        elsif @command_history_index > 0
          @command_history_index -= 1
          self.current_input_str = @command_history[@command_history_index].dup
        end
      elsif args.inputs.keyboard.key_down.left
        prompt.move_cursor_left
      elsif args.inputs.keyboard.key_down.right
        prompt.move_cursor_right
      elsif inputs_scroll_up_full? args
        scroll_up_full
      elsif inputs_scroll_down_full? args
        scroll_down_full
      elsif inputs_scroll_up_half? args
        scroll_up_half
      elsif inputs_scroll_down_half? args
        scroll_down_half
      elsif inputs_clear_command? args
        prompt.clear
        @command_history_index = -1
        @nonhistory_input      = ''
      elsif args.inputs.keyboard.key_down.backspace || args.inputs.keyboard.key_down.delete
        prompt.backspace
      elsif args.inputs.keyboard.key_down.tab
        prompt.autocomplete
      end

      args.inputs.keyboard.key_down.clear
      args.inputs.keyboard.key_up.clear
      args.inputs.keyboard.key_held.clear
    end

  end
end
