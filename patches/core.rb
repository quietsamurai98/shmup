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