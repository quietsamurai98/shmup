class Array
  def map(&block)
    return to_enum :collect unless block
    i = 0
    l = self.length
    ary = []
    while i < l
      ary.push(block.call(self.value(i)))
      i += 1
    end
    ary
  end
end

module GTK
  class Inputs
    # @return [Integer]
    def left_right
      (!self.right == !self.left ? 0 : self.right ? 1 : -1) # + (self.controller_one&.sum_analog_x_perc || 0)
    end

    # @return [Integer]
    def up_down
      (!self.up == !self.down ? 0 : self.up ? 1 : -1) # + (self.controller_one&.sum_analog_y_perc || 0)
    end
  end
  class Controller
    def fire
      self.a || self.b || self.x || self.y || self.r1 || self.r2 || self.r3 || self.l1 || self.l2 || self.l3
    end
    def sum_analog_x_perc
      self.right_analog_x_perc + self.left_analog_x_perc
    end
    def sum_analog_y_perc
      self.right_analog_x_perc + self.left_analog_y_perc
    end
  end
end