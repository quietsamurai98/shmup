class SimpleCircleBullet < Sprite
  attr_accessor :collider

  # @return [nil]
  # @param [Integral] x
  # @param [Integral] y
  # @param [Integral] rad
  # @param [Integral] vx
  # @param [Integral] vy
  # @param [Integral] r
  # @param [Integral] g
  # @param [Integral] b
  def initialize(x, y, rad, vx, vy, r, g, b)
    @x = x
    @y = y
    @rad = rad
    @w = 2 * rad
    @h = 2 * rad
    @path = 'sprite/circle.png'
    @vx = vx
    @vy = vy
    @r = r
    @g = g
    @b = b
    @a = 255
    @collider = GeoGeo::Circle.new(x + rad, y + rad, rad)
  end

  # @return [nil]
  def move
    @x += @vx
    @y += @vy
    @collider.shift(@vx, @vy)
  end
end

class SimpleBoxBullet
  attr_accessor :x, :y, :w, :h, :vx, :vy, :r, :g, :b, :a, :collider

  # @return [nil]
  # @param [Integral] x
  # @param [Integral] y
  # @param [Integral] w
  # @param [Integral] h
  # @param [Integral] vx
  # @param [Integral] vy
  def initialize(x, y, w, h, vx, vy)
    @x = x
    @y = y
    @w = w
    @h = h
    @vx = vx
    @vy = vy
    @r = 255
    @g = 0
    @b = 0
    @a = 255
    @collider = GeoGeo::Box.new_drgtk(x, y, w, h)
  end

  # @return [nil]
  def move
    @x += @vx
    @y += @vy
    @collider.shift(@vx, @vy)
  end

  # @return [nil]
  def primitive_marker
    :solid
  end

  # @return [nil]
  def delete

  end
end