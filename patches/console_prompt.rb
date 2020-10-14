# Copyright 2019 DragonRuby LLC
# MIT License
# console_prompt.rb has been released under MIT (*only this file*).

# Contributors outside of DragonRuby who also hold Copyright:
# - Kevin Fischer: https://github.com/kfischer-okarin

module GTK
  class Console
    class Prompt

      def initialize(font_style:, text_color:, console_text_width:)
        @prompt = '-> '
        @current_input_str = ''
        @font_style = font_style
        @text_color = text_color
        @cursor_color = Color.new [187, 21, 6]
        @console_text_width = console_text_width

        @cursor_position = 0

        @last_autocomplete_prefix = nil
        @next_candidate_index = 0
      end

      def current_input_str=(str)
        @current_input_str = str
        @cursor_position = str.length
      end

      def <<(str)
        @current_input_str = @current_input_str[0...@cursor_position] + str + @current_input_str[@cursor_position..-1]
        @cursor_position += str.length
        @current_input_changed_at = Kernel.global_tick_count
        reset_autocomplete
      end

      def backspace
        return if current_input_str.length.zero? || @cursor_position.zero?

        @current_input_str = @current_input_str[0...(@cursor_position - 1)] + @current_input_str[@cursor_position..-1]
        @cursor_position -= 1
        reset_autocomplete
      end

      def move_cursor_left
        @cursor_position -= 1 if @cursor_position > 0
      end

      def move_cursor_right
        @cursor_position += 1 if @cursor_position < current_input_str.length
      end

      def clear
        @current_input_str = ''
        @cursor_position = 0
        reset_autocomplete
      end

      def render(args, x:, y:)
        args.outputs.reserved << font_style.label(x: x, y: y, text: "#{@prompt}#{current_input_str}", color: @text_color)
        args.outputs.reserved << font_style.label(x: x - 4, y: y + 3, text: (" " * (@prompt.length + @cursor_position)) + "|", color: @cursor_color)
      end
    end
  end
end
