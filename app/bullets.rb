# A bullet MUST be a duck-typed renderable.
# SimpleCircleBullet is an example of a sprite bullet, while
# SimpleBoxBullet is an example of a solid bullet.
class AbstractBullet
  attr_accessor :damage
end

class SimpleCircleBullet < AbstractBullet
  attr_accessor :collider, :x, :y

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
  def initialize(x, y, rad, vx, vy, r, g, b, damage = 1)
    @x = x
    @y = y
    @rad = rad
    @vx = vx
    @vy = vy
    @r = r
    @g = g
    @b = b
    @collider = GeoGeo::Circle.new(x + rad, y + rad, rad)
    @damage = damage
  end

  # @return [nil]
  def move
    @x += @vx
    @y += @vy
    @collider.shift(@vx, @vy)
  end

  # @return [nil]
  # @param [FFI::Draw] ffi_draw
  def draw_override(ffi_draw)
    ffi_draw.draw_sprite_3(@x - @rad, @y - @rad, 2 * @rad, 2 * @rad, "sprites/rad_3_bullet.png", nil, nil, @r, @g, @b,
                           nil, nil, nil, nil, nil, nil,
                           nil, nil, nil, nil, nil, nil)
  end

  # @return [Symbol]
  def primitive_marker
    :sprite
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
    @collider = GeoGeo::Box.new_drgtk(x, y, w, h)
  end

  # @return [nil]
  def move
    @x += @vx
    @y += @vy
    @collider.shift(@vx, @vy)
  end

  # @return [nil]
  # @param [FFI::Draw] ffi_draw
  def draw_override(ffi_draw)
    ffi_draw.draw_solid(@x, @y, @w, @h, 255, 0, 0, 255)
  end

  # @return [Symbol]
  def primitive_marker
    :sprite
  end
end