require 'patches/console.rb'
require 'patches/console_prompt.rb'
require 'patches/framerate_diagnostics.rb'
require 'lib/geo_geo.rb'
require 'lib/shmup_lib.rb'

class GameState
  def initialize

  end
end


# @param [GTK::Args] args
# @return [nil]
def tick(args)
  args.gtk.hide_cursor
  if args.inputs.keyboard.key_down.r || Kernel.tick_count == 0
    $boss_y = 722
    $boss_spawn = 0
    args.state.area_width = 540
    args.state.game_tick = -1
    init(args)
  end
  args.state.game_tick += 1
  # @type [ShmupLib::CollisionManager] cm
  cm = args.state.cm
  # @type [Player] player
  player = args.state.player

  if args.state.area_width < 1280 && (args.inputs.keyboard.key_held.z || args.state.area_width != 540)
    if args.state.area_width == 540
      # args.outputs.sounds << 'sounds/boss_alarm.wav'
    end
    args.state.area_width = args.state.area_width + 2.5
  end
  area_width = args.state.area_width
  if area_width == 1280
    if $boss_y > 720 - 128
      $boss_y -= 1
    end
    if $boss_spawn < 25 && args.state.game_tick % 32 == 0 && $boss_y < 670
      spawn_enemy(cm, :boss)
      $boss_spawn += 1
    end
    args.outputs.primitives << {
        x: 40,
        y: $boss_y,
        w: 1200,
        h: 128,
        path: 'sprites/boss.png'
    }
  end

  # spawn_enemy(cm, :fig8) if args.state.game_tick % 37 == 0 && args.state.game_tick.between?(120, 120 + 37 * 17)

  args.outputs.background_color = [0, 0, 0]

  tick_player_bullets(cm)
  tick_enemy_bullets(cm)

  cm_tick(cm)

  player.do_tick(args, cm)
  tick_enemies(cm, player)

  args.outputs.primitives << player.renderable
  args.outputs.primitives << cm.get_group(:enemies).map(&:renderable)
  args.outputs.primitives << cm.get_group(:enemy_bullets)
  args.outputs.primitives << cm.get_group(:player_bullets)
  args.outputs.primitives << {x: 0, y: 0, w: 640 - area_width / 2, h: 720, r: 25}.solid
  args.outputs.primitives << {x: 640 + area_width / 2, y: 0, w: 640 - area_width / 2, h: 720, r: 25}.solid

  args.outputs.static_solids.each do |s|
    s.y = (s.y + 10 - s[:v]) % 740 - 10
  end
  args.outputs.labels << [
      {x: 275 - area_width / 2, y: 30, text: "FPS : #{$gtk.current_framerate.to_s.to_i}", r: 255, g: 0, b: 0},
      {x: 275 - area_width / 2, y: 60, text: "Possible Collision Pairs : #{cm.get_group(:enemies).length * cm.get_group(:player_bullets).length + cm.get_group(:enemy_bullets).length}", r: 255, g: 0, b: 0},
      {x: 275 - area_width / 2, y: 90, text: "Player Bullet Count : #{cm.get_group(:player_bullets).length}", r: 255, g: 0, b: 0},
      {x: 275 - area_width / 2, y: 120, text: "Enemy Bullet Count : #{cm.get_group(:enemy_bullets).length}", r: 255, g: 0, b: 0},
      {x: 275 - area_width / 2, y: 150, text: "Enemy Count : #{cm.get_group(:enemies).length}", r: 255, g: 0, b: 0},
  ]
end

# @param [ShmupLib::CollisionManager] cm
def tick_player_bullets(cm)
  arr = cm.get_group(:player_bullets)
  i = 0
  il = arr.length
  while i < il
    arr[i].move
    if arr[i].y > 730
      cm.del_from_group(:player_bullets, arr[i])
      i -= 1
      il -= 1
    end
    i += 1
  end
end

# @param [ShmupLib::CollisionManager] cm
def tick_enemy_bullets(cm)
  arr = cm.get_group(:enemy_bullets)
  i = 0
  il = arr.length
  while i < il
    arr[i].move
    if arr[i].y < -10
      cm.del_from_group(:enemy_bullets, arr[i])
      i -= 1
      il -= 1
    end
    i += 1
  end
end

# @param [ShmupLib::CollisionManager] cm
def spawn_enemy(cm, sym)
  if sym == :fig8
    cm.add_to_group(:enemies, Figure8Enemy.new(0.01))
  end
  if sym == :boss
    cm.add_to_group(:enemies, BossFigure8Enemy.new(Math::PI / 400))
  end
end

# @param [ShmupLib::CollisionManager] cm
def tick_enemies(cm, player)
  arr = cm.get_group(:enemies)
  i = 0
  il = arr.length
  while i < il
    arr[i].do_tick(cm, player)
    if false # TODO
      cm.del_from_group(:enemies, arr[i])
      i -= 1
      il -= 1
    end
    i += 1
  end
end

# @param [ShmupLib::CollisionManager] cm
# @return [nil]
def cm_tick(cm)
  enemy_pb_collisions = cm.first_collisions_between(:enemies, :player_bullets)
  unless enemy_pb_collisions.empty?
    enemy_pb_collisions.keys.each do |e|
      cm.del_from_group(:enemies, e)
    end
    enemy_pb_collisions.values.flatten.each do |b|
      cm.del_from_group(:player_bullets, b)
      b.delete
    end
  end
  if cm.any_collision_between?(:players, :enemy_bullets)
    $gtk.reset
  end
end

# @param [GTK::Args] args
# @return [nil]
def init(args)
  player = Player.new
  dx = 60
  enemies = [
      SimpleWideEnemy.new(640 - 3 * dx, 600, 0.5),
      SimpleWideEnemy.new(640 - dx, 600, 1),
      SimpleWideEnemy.new(640 + dx, 600, 0.5),
      SimpleWideEnemy.new(640 + 3 * dx, 600, 1),
      SimpleWideEnemy.new(640 - 3 * dx, 550, 1.5),
      SimpleWideEnemy.new(640 - dx, 550, 2),
      SimpleWideEnemy.new(640 + dx, 550, 1.5),
      SimpleWideEnemy.new(640 + 3 * dx, 550, 2),
      SimpleWideEnemy.new(640 - 3 * dx, 500, 2.5),
      SimpleWideEnemy.new(640 - dx, 500, 3),
      SimpleWideEnemy.new(640 + dx, 500, 2.5),
      SimpleWideEnemy.new(640 + 3 * dx, 500, 3),
      SimpleWideEnemy.new(640 - 3 * dx, 450, 3.5),
      SimpleWideEnemy.new(640 - dx, 450, 4),
      SimpleWideEnemy.new(640 + dx, 450, 3.5),
      SimpleWideEnemy.new(640 + 3 * dx, 450, 4),
      SimpleWideEnemy.new(640 - 3 * dx, 400, 4.5),
      SimpleWideEnemy.new(640 - dx, 400, 5),
      SimpleWideEnemy.new(640 + dx, 400, 4.5),
      SimpleWideEnemy.new(640 + 3 * dx, 400, 5),
  ]
  cm = ShmupLib::CollisionManager.new
  cm.add_group(:players)
  cm.add_group(:enemies)
  cm.add_group(:player_bullets)
  cm.add_group(:enemy_bullets)
  cm.add_to_group(:players, player)
  args.state.cm = cm
  args.state.player = player
  args.outputs.static_solids.clear
  200.times {
    args.outputs.static_solids << {x: rand * 1278, y: rand * 730, w: 2, h: 2, r: 255, g: 255, b: 255, v: rand * 0.25 + 1}
  }
end

class Sprite
  attr_accessor :x, :y, :w, :h, :path, :angle, :a, :r, :g, :b,
                :source_x, :source_y, :source_w, :source_h,
                :tile_x, :tile_y, :tile_w, :tile_h,
                :flip_horizontally, :flip_vertically,
                :angle_anchor_x, :angle_anchor_y

  def primitive_marker
    :sprite
  end
end

class Player
  attr_accessor :collider, :x, :y

  def initialize
    @x = 640
    @y = 64
    @collider = GeoGeo::Polygon.new([[-16, -16], [0, 16], [16, -16]],)
    @collider.set_center([@x, @y])
    @cur_fire_cooldown = 0
    @max_fire_cooldown = 5
    @cur_barrel = 0
    @num_barrel = 4
  end

  # @param [GTK::Args] args
  # @param [ShmupLib::CollisionManager] cm
  def do_tick(args, cm)
    # @type [Array] keys_dh
    keys_dh = args.inputs.keyboard.key[:down_or_held]
    dx, dy = 0, 0
    dx += 2 if keys_dh.include?(:d)
    dx -= 2 if keys_dh.include?(:a)
    dy += 1 if keys_dh.include?(:w)
    dy -= 1 if keys_dh.include?(:s)
    shift(dx, dy) if dx != 0 || dy != 0
    fire(cm, :ripple, dx * 0.1, dy) if args.inputs.mouse.button_left || keys_dh.include?(:q) && !keys_dh.include?(:e)
    fire(cm, :salvo, dx * 0.1, dy) if keys_dh.include?(:e) && !keys_dh.include?(:q) && !args.inputs.mouse.button_left
    fire(cm, :volley, dx * 0.1, dy) if keys_dh.include?(:q) && keys_dh.include?(:e) && !args.inputs.mouse.button_left
    @cur_fire_cooldown -= 1 if @cur_fire_cooldown > 0
  end

  # @param [Integral] dx
  # @param [Integral] dy
  # @return [nil]
  def shift(dx, dy)
    @x += dx
    @y += dy
    @collider.shift(dx, dy)
  end

  # @param [ShmupLib::CollisionManager] cm
  # @param [Symbol] mode
  # @return [nil]
  def fire(cm, mode, dx, dy)
    if @cur_fire_cooldown == 0
      ripple_fire(cm, dx, dy) if mode == :ripple
      volley_fire(cm, dx, dy) if mode == :volley
      salvo_fire(cm, dx, dy) if mode == :salvo
      @cur_fire_cooldown = @max_fire_cooldown
    end
  end

  # @param [ShmupLib::CollisionManager] cm
  def ripple_fire(cm, dx, dy)
    bx, by = [
        [-10, -2],
        [-4, -2],
        [2, -2],
        [8, -2],
    ][@cur_barrel]
    cm.add_to_group(:player_bullets, SimpleBoxBullet.new(@x + bx, @y + by, 2, 3, 0 + dx, 3))
    @cur_barrel = (@cur_barrel + 1) % @num_barrel
  end

  # @param [ShmupLib::CollisionManager] cm
  def salvo_fire(cm, dx, dy)
    if @cur_barrel == 0
      cm.add_to_group(
          :player_bullets,
          SimpleBoxBullet.new(@x - 10, @y - 2, 2, 3, 0 + dx, 3),
          SimpleBoxBullet.new(@x - 4, @y - 2, 2, 3, 0 + dx, 3),
          SimpleBoxBullet.new(@x + 2, @y - 2, 2, 3, 0 + dx, 3),
          SimpleBoxBullet.new(@x + 8, @y - 2, 2, 3, 0 + dx, 3)
      )
    end
    @cur_barrel = (@cur_barrel + 1) % @num_barrel
  end

  # @param [ShmupLib::CollisionManager] cm
  def volley_fire(cm, dx, dy)
    if @cur_barrel == 0
      cm.add_to_group(:player_bullets, SimpleBoxBullet.new(@x - 10, @y - 2, 2, 3, 0 + dx, 3))
      cm.add_to_group(:player_bullets, SimpleBoxBullet.new(@x + 2, @y - 2, 2, 3, 0 + dx, 3))
    end
    if @cur_barrel == 2
      cm.add_to_group(:player_bullets, SimpleBoxBullet.new(@x - 4, @y - 2, 2, 3, 0 + dx, 3))
      cm.add_to_group(:player_bullets, SimpleBoxBullet.new(@x + 8, @y - 2, 2, 3, 0 + dx, 3))
    end
    @cur_barrel = (@cur_barrel + 1) % @num_barrel
  end

  # @return [Array]
  def renderable
    out = [
        {
            x: @x - 16,
            y: @y - 16,
            w: 32,
            h: 32,
            path: 'sprites/player.png'
        }.sprite
    ]
    out.concat(@collider.verts.each_cons(2).map do
      # @type [Array] a
      # @type [Array] b
    |a, b|
      {
          x: a.x,
          y: a.y,
          x2: b.x,
          y2: b.y,
          r: 0,
          g: 255,
          b: 0,
          a: 128
      }.line
    end) if false
    out
  end
end

class SimpleCircleBullet < Sprite
  attr_accessor :collider

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