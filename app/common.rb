class Sprite
  attr_accessor :x, :y, :w, :h, :path, :angle, :a, :r, :g, :b,
                :source_x, :source_y, :source_w, :source_h,
                :tile_x, :tile_y, :tile_w, :tile_h,
                :flip_horizontally, :flip_vertically,
                :angle_anchor_x, :angle_anchor_y

  def primitive_marker
    :sprite
  end

  def initialize(x: nil, y: nil, w: nil, h: nil, path: nil, angle: nil, a: nil, r: nil, g: nil, b: nil,
                 source_x: nil, source_y: nil, source_w: nil, source_h: nil,
                 tile_x: nil, tile_y: nil, tile_w: nil, tile_h: nil,
                 flip_horizontally: nil, flip_vertically: nil,
                 angle_anchor_x: nil, angle_anchor_y: nil)
    @x = x
    @y = y
    @w = w
    @h = h
    @path = path
    @angle = angle
    @a = a
    @r = r
    @g = g
    @b = b
    @source_x = source_x
    @source_y = source_y
    @source_w = source_w
    @source_h = source_h
    @tile_x = tile_x
    @tile_y = tile_y
    @tile_w = tile_w
    @tile_h = tile_h
    @flip_horizontally = flip_horizontally
    @flip_vertically = flip_vertically
    @angle_anchor_x = angle_anchor_x
    @angle_anchor_y = angle_anchor_y
  end
end
