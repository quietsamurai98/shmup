module GTK
  class Console
    # The console normally uses reverse scrolling. This patch makes it use natural scrolling.
    def mouse_wheel_scroll(args)
      @inertia = args.inputs.mouse.click ? 0 : (@inertia||0)*0.7 + (0 <=> (args.inputs.mouse.wheel&.y || 0))
      @log_offset = (@log_offset + (0 <=> @inertia)).clamp(0, @log.size) unless @inertia.abs < 0.01
    end
  end
end
