class AbstractEnemy
  # @return [GeoGeo::Shape2D]
  attr_accessor :collider
  attr_accessor :health

  # @return [nil]
  # @param [Array<Object>] arguments
  def initialize(*arguments)
    @collider = GeoGeo::Shape2D.new(0, 0, 0, 0)
  end

  # @return [nil]
  def update_pos

  end

  # @return [nil]
  # @param [ShmupLib::CollisionManager] cm
  # @param [Player] player
  def do_tick(cm, player) end

  # @return [Array]
  def renderables
    []
  end

  def <=> o
    @collider.bottom <=> o.collider.bottom
  end

  # @return [Integer]
  # @param [AbstractEnemy] other
  def compare_bottom(other)
    @collider.bottom <=> other.collider.bottom
  end

  # @return [Integer]
  # @param [AbstractEnemy] other
  def compare_left(other)
    @collider.left <=> other.collider.left
  end
end

class EnemyLemni < AbstractEnemy
  def initialize(speed, initial_orbit_width, final_orbit_width, orbit_height, orbit_center_x, orbit_center_y, orbit_y_delta, fire_rate, fire_delay)
    @health = 3
    @t = 0
    @speed = speed
    @age = -1
    @collider = GeoGeo::Circle.new(-100, -100, 16)
    @turret_sprite_angle = -90
    @initial_orbit_width = initial_orbit_width
    @final_orbit_width = final_orbit_width
    @orbit_height = orbit_height
    @orbit_center_x = orbit_center_x
    @orbit_center_y = orbit_center_y
    @orbit_y_delta = orbit_y_delta
    @fire_rate = fire_rate
    @fire_delay = fire_delay
    update_pos
  end

  def update_pos
    x_factor = @final_orbit_width
    x_factor += (@initial_orbit_width - @final_orbit_width) * (1 - @t) if @t < 1
    tmp_x = Math.cos(@t)
    @x = tmp_x * x_factor + @orbit_center_x
    tmp_y = Math.sin(2 * (@t + @orbit_y_delta))
    @y = tmp_y * @orbit_height + @orbit_center_y
    @collider.set_center(@x, @y)
    tmp_x *= 0 <=> x_factor
    tmp_y *= 0 <=> @orbit_height
    @x_thrust = tmp_x
    @y_thrust = tmp_y
  end

  def do_tick(cm, player)
    @t += @speed
    @age += 1
    update_pos
    angle_to_player = Math.atan2(player.y - @y, player.x - @x)
    @turret_sprite_angle = angle_to_player.to_degrees
    angle_to_player += (rand - 0.5) * 0.0
    cm.add_to_group(
        :enemy_bullets,
        SimpleCircleBullet.new(@x + 15 * Math.cos(angle_to_player), @y + 15 * Math.sin(angle_to_player), 3, 2 * Math.cos(angle_to_player), 2 * Math.sin(angle_to_player), 0, 255, 0),
    ) if (@age - @fire_delay) % @fire_rate == 0 && (@age - @fire_delay) >= 0
  end

  # @return [nil]
  # @param [FFI::Draw] ffi_draw
  def draw_override(ffi_draw)
    if @x_thrust > 0.5
      ffi_draw.draw_sprite_2(@x - 20, @y - 20, 40, 40, 'sprites/circle_enemy_thruster.png', 180, nil)
    elsif @x_thrust < -0.5
      ffi_draw.draw_sprite(@x - 20, @y - 20, 40, 40, 'sprites/circle_enemy_thruster.png')
    end
    if @y_thrust > 0.5
      ffi_draw.draw_sprite_2(@x - 20, @y - 20, 40, 40, 'sprites/circle_enemy_thruster.png', 270, nil)
    elsif @y_thrust < -0.5
      ffi_draw.draw_sprite_2(@x - 20, @y - 20, 40, 40, 'sprites/circle_enemy_thruster.png', 90, nil)
    end
    ffi_draw.draw_sprite(@x - 20, @y - 20, 40, 40, 'sprites/circle_enemy.png')
    ffi_draw.draw_sprite_2(@x - 20, @y - 20, 40, 40, 'sprites/circle_enemy_turret.png', @turret_sprite_angle, nil)
  end

  # @return [Symbol]
  def primitive_marker
    :sprite
  end
end

class BossFigure8Enemy
  attr_accessor :collider

  def initialize(speed)
    @t = 0
    @speed = speed
    @lis_a = 1
    @lis_b = 2
    @lis_d = 0
    @age = 0
    @collider = GeoGeo::Circle.new(-100, -100, 16)
    @turret_sprite_angle = -90
    update_pos
  end

  def update_pos
    if @t < Math::PI
      @x = -Math.sin(@t) * 300 + 360
      @y = Math.cos(@t) * 340 + 500
      case @t / Math::PI
      when 0.0..1.0
        @ship_sprite_angle = 0
        @ship_sprite_path = 'sprites/circle_enemy.png'
      else
        @ship_sprite_angle = 0
        @ship_sprite_path = 'sprites/circle_enemy.png'
      end
    else
      @x = Math.sin(1 * @t + 3 * Math::PI / 4) * 400 + 640
      @y = Math.sin(2 * @t + 3 * Math::PI / 2) * 200 + 360
      @ship_sprite_angle = 0
      @ship_sprite_path = 'sprites/circle_enemy.png'
    end

    @collider.set_center(@x, @y)
  end

  def do_tick(cm, player)
    @t += @speed
    @turret_sprite_angle = Math.atan2(player.y - @y, player.x - @x).to_degrees if @age % 10 == 0
    @age += 1
    update_pos
    cm.add_to_group(
        :enemy_bullets,
        SimpleBoxBullet.new(@x, @y, 2, 2, 0, -3),
    ) if @age % 30 == 0 && false
  end

  def renderables
    [
        {
            x: @x - 20,
            y: @y - 20,
            w: 40,
            h: 40,
            path: @ship_sprite_path || 'sprites/circle_enemy.png',
            angle: @ship_sprite_angle || 0
        }.sprite,
        {
            x: @x - 20,
            y: @y - 20,
            w: 40,
            h: 40,
            path: 'sprites/circle_enemy_turret.png',
            angle: @turret_sprite_angle || 0
        }.sprite
    ]
  end
end

class SimpleWideEnemy
  attr_accessor :collider
  # @return [nil]
  # @param [Integral] x
  # @param [Integral] y
  def initialize(x, y, init_delay)
    @x = x
    @ix = x
    @y = y
    @iy = y
    @collider = GeoGeo::Box.new(x - 24, x + 24, y - 4, y + 8)
    @age = 0
    @max_cooldown = 120
    @cur_cooldown = @max_cooldown * init_delay
  end

  # @param [ShmupLib::CollisionManager] cm
  def do_tick(cm, player)
    @age += 1
    @x = Math.sin(((@age % (@max_cooldown + 1)) / @max_cooldown) * 2 * Math::PI) * 20 * (@y % 100 == 0 ? 1 : -1) + @ix
    if @cur_cooldown == 0
      cm.add_to_group(
          :enemy_bullets,
          SimpleBoxBullet.new(@x - 22, @y - 7 - 5, 2, 5, 0, -4),
          SimpleBoxBullet.new(@x - 12, @y - 7 - 5, 2, 5, 0, -4),
          SimpleBoxBullet.new(@x - 01, @y - 7 - 5, 2, 5, 0, -4),
          SimpleBoxBullet.new(@x + 10, @y - 7 - 5, 2, 5, 0, -4),
          SimpleBoxBullet.new(@x + 20, @y - 7 - 5, 2, 5, 0, -4),
      )
      @cur_cooldown = @max_cooldown + 1
    end
    @collider = GeoGeo::Box.new(@x - 24, @x + 24, @y - 4, @y + 8)
    @cur_cooldown -= 1

  end

  def renderables
    out = [
        {
            x: @x - 24,
            y: @y - 8,
            w: 48,
            h: 16,
            path: 'sprites/wide_enemy.png'
        }.sprite
    ]
    out << {
        x: @collider.x,
        y: @collider.y,
        w: @collider.w,
        h: @collider.h,
        r: 0,
        g: 255,
        b: 0,
        a: 128
    }.border if false
    out
  end
end

class Boss1 < AbstractEnemy
  attr_accessor :x, :y, :age

  def initialize(x, y, moving)
    @x = x
    @y = y
    @age = 0
    @moving = moving
    @collider = GeoGeo::Polygon.new(
        [
            [0, 80],
            [60, 64],
            [73, 53],
            [173, 53],
            [208, 33],
            [318, 33],
            [357, 0],
            [443, 0],
            [482, 33],
            [592, 33],
            [627, 53],
            [727, 53],
            [740, 64],
            [800, 80],
            [800, 157],
            [632, 200],
            [168, 200],
            [0, 157],
        ],
        [400, 100]
    )
  end

  def update_pos
    @collider.set_center([@x, @y])
  end

  def do_tick(cm, player)
    @age += 1
  end

  def renderables
    [self]
  end

  # @return [nil]
  # @param [FFI::Draw] ffi_draw
  def draw_override(ffi_draw)
    ffi_draw.draw_sprite(@x - 400, @y - 100, 800, 200, "sprites/boss1/main.png")
    ffi_draw.draw_sprite(@x - 359, @y + 71, 110, @moving ? 20 : 20, "sprites/boss1/thruster_fx/orange#{(@age / 6).floor % 3 + 4}.png")
    ffi_draw.draw_sprite(@x - 359, @y + 71, 110, @moving ? 20 : 20, "sprites/boss1/thruster_fx/red#{(@age / 6 + 2).floor % 3 + 4}.png")
    ffi_draw.draw_sprite(@x - 359, @y + 71, 110, @moving ? 20 : 20, "sprites/boss1/thruster_fx/yellow#{(@age / 6 + 4).floor % 3 + 4}.png")
    ffi_draw.draw_sprite(@x - 55, @y + 71, 110, @moving ? 20 : 20, "sprites/boss1/thruster_fx/orange#{(@age / 6).floor % 6 + 1}.png")
    ffi_draw.draw_sprite(@x - 55, @y + 71, 110, @moving ? 20 : 20, "sprites/boss1/thruster_fx/red#{(@age / 6 + 1).floor % 6 + 1}.png")
    ffi_draw.draw_sprite(@x - 55, @y + 71, 110, @moving ? 20 : 20, "sprites/boss1/thruster_fx/yellow#{(@age / 6 + 2).floor % 6 + 1}.png")
    ffi_draw.draw_sprite(@x + 249, @y + 71, 110, @moving ? 20 : 20, "sprites/boss1/thruster_fx/orange#{(@age / 6).floor % 3 + 1}.png")
    ffi_draw.draw_sprite(@x + 249, @y + 71, 110, @moving ? 20 : 20, "sprites/boss1/thruster_fx/red#{(@age / 6 + 2).floor % 3 + 1}.png")
    ffi_draw.draw_sprite(@x + 249, @y + 71, 110, @moving ? 20 : 20, "sprites/boss1/thruster_fx/yellow#{(@age / 6 + 4).floor % 3 + 1}.png")
    # blast_frames = 9.times.flat_map {|i| [i]*(i > 7 ? 6 : 4) } + [9]*30
    # [73, 80, 82, 83, 85, 87, 90, 91].each_with_index do |n,i|
    #   ffi_draw.draw_sprite_3(640-64+(32*(i%4)), 550+32*(i.fdiv(4.0).floor), 32, 32, "sprites/explosions/32_#{n}.png",nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,32*(@age % 90),0,32,32)
    # end
    if false
      @collider.verts.each_cons(2).map do
        # @type [Array] a
        # @type [Array] b
      |a, b|
        ffi_draw.draw_line(a.x, a.y, b.x, b.y, 0, 255, 0, 255)
      end
    end
  end

  # @return [Symbol]
  def primitive_marker
    :sprite
  end
end

class BossLaserTurret < AbstractEnemy
  attr_reader :beam_collider
  def initialize(x, y)
    @turret_sprite_angle = -90
    @internal_angle = -90
    @x = x
    @y = y
    @collider = GeoGeo::Polygon.new([[70, 32], [118, 45], [118, 82], [70, 95], [57, 95], [41, 86], [32, 69], [32, 57], [41, 41], [58, 32]], [64, 64])
    @collider.set_center([@x, @y])
    @collider.theta = @turret_sprite_angle.to_radians
    @beam_collider = GeoGeo::Polygon.new([[118, 46], [119, 46], [119, 80], [118, 80], [118, 82]], [64, 64])
    @beam_collider.set_center([@x, @y])
    @beam_collider.theta = @turret_sprite_angle.to_radians
    @age = -1
    @phase = 1
    @moved = 0
    @health = 25
  end

  def update_pos(dx, dy)
    @x += dx
    @y += dy
    @collider.set_center([@x, @y])
    @beam_collider.set_center([@x, @y]) if @beam_collider != @collider
    @moved = @age + 1
  end

  def do_tick(cm, player)
    @age += 1
    phase_change = (@age / 90 - 1).floor % 6 - @phase != 0 && @y < 720
    @phase += (@age / 90 - 1).floor % 6 - @phase if @y < 720
    angle_to_player = Math.atan2(player.y - @y, player.x - @x).to_degrees
    delta_angle = (angle_to_player - 90) % 360 - (@internal_angle - 90) % 360
    if @phase < 4
      @internal_angle += delta_angle.clamp(-1, 1)
      @internal_angle = -90 if @moved == @age
      @turret_sprite_angle = @internal_angle
      @collider.theta = @turret_sprite_angle.to_radians if delta_angle.abs > 0.0001
      @beam_collider.theta = @turret_sprite_angle.to_radians if delta_angle.abs > 0.0001
    end
    # Since we are using the turret itself the damage dealer, we need to change the collider to match the visual hitbox.
    if phase_change
      if @phase == 0
        @beam_collider = GeoGeo::Polygon.new([[118, 46], [119, 46], [119, 80], [118, 80], [118, 82]], [64, 64])
        @beam_collider.set_center([@x, @y])
        @beam_collider.theta = @turret_sprite_angle.to_radians
      end
      if @phase == 5
        @beam_collider = GeoGeo::Polygon.new([[118, 48], [1618, 48], [1618, 80], [118, 80], [118, 82]], [64, 64])
        @beam_collider.set_center([@x, @y])
        @beam_collider.theta = @turret_sprite_angle.to_radians
      end
    end
  end

  # @return [nil]
  # @param [FFI::Draw] ffi_draw
  def draw_override(ffi_draw)
    ffi_draw.draw_sprite_2(@x - 1500, @y - 16, 3000, 32, 'sprites/tmp_beam.png', @turret_sprite_angle.round, nil) if @phase == 5
    ffi_draw.draw_sprite_2(@x - 64, @y - 64, 128, 128, "sprites/boss_beam_turret_#{(@phase).floor}.png", @turret_sprite_angle, nil)
    if false
      @collider.verts.each_cons(2).map do
        # @type [Array] a
        # @type [Array] b
      |a, b|
        ffi_draw.draw_line(a.x, a.y, b.x, b.y, 0, 255, 0, 255)
      end
      @beam_collider.verts.each_cons(2).map do
        # @type [Array] a
        # @type [Array] b
      |a, b|
        ffi_draw.draw_line(a.x, a.y, b.x, b.y, 255, 0, 255, 255)
      end
    end
  end

  # @return [Symbol]
  def primitive_marker
    :sprite
  end
end