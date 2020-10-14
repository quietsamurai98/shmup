# A bullet MUST be a duck-typed renderable.
# SimpleCircleBullet is an example of a sprite bullet, while
# SimpleBoxBullet is an example of a solid bullet.
class AbstractBullet
  attr_accessor :damage
end

class SimpleCircleBullet < AbstractBullet
  include SpriteModule
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
  # @param [Integral] damage
  def initialize(x, y, rad, vx, vy, r, g, b, damage=1)
    @x = x
    @y = y
    @rad = rad
    @w = 2 * rad
    @h = 2 * rad
    @path = "sprites/rad_#{rad.to_i}_bullet.png"
    @vx = vx
    @vy = vy
    @r = r
    @g = g
    @b = b
    @a = 255
    @collider = GeoGeo::Circle.new(x + rad, y + rad, rad)
    @damage = damage
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
  # @param [Integral] damage
  def initialize(x, y, w, h, vx, vy, damage = 1)
    @damage = damage
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
end