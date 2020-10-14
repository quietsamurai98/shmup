class AbstractEnemy
  attr_accessor :collider
  attr_accessor :health

  # @return [nil]
  # @param [Array<Object>] arguments
  def initialize(*arguments) end

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
end

class EnemyLemni < AbstractEnemy
  def initialize(speed, initial_orbit_width, final_orbit_width, orbit_height, fire_rate, fire_delay)
    @health = 3
    @t = 0
    @speed = speed
    @age = -1
    @collider = GeoGeo::Circle.new(-100, -100, 16)
    @turret_sprite_angle = -90
    @initial_orbit_width = initial_orbit_width
    @final_orbit_width = final_orbit_width
    @orbit_height = orbit_height
    @fire_rate = fire_rate
    @fire_delay = fire_delay
    update_pos
  end

  def update_pos
    x_factor = @final_orbit_width
    x_factor += (@initial_orbit_width - @final_orbit_width) * (1 - @t) if @t < 1
    dx, dy = @x || 0, @y || 0
    @x = Math.cos(@t) * x_factor + 640
    @y = Math.sin(2 * @t) * 100 + 500
    @collider.set_center(@x, @y)

    @ship_sprite_path = 'sprites/circle_enemy_thrust2.png'
    case 4 * (@t % (Math::PI * 2)) / (Math::PI)
    when 0.0..0.5
      @ship_sprite_angle = -90
    when 0.5..2.5
      @ship_sprite_angle = 0
    when 2.5..4.5
      @ship_sprite_angle = 180
    when 4.5..6.5
      @ship_sprite_angle = 90
    when 6.5..8.0
      @ship_sprite_angle = -90
    else
      @ship_sprite_angle = 0
      @ship_sprite_path = 'sprites/circle_enemy.png'
    end
  end

  def do_tick(cm, player)
    @t += @speed
    @age += 1
    update_pos
    angle_to_player = Math.atan2(player.y - @y, player.x - @x)
    @turret_sprite_angle = angle_to_player.to_degrees
    cm.add_to_group(
        :enemy_bullets,
        SimpleCircleBullet.new(@x+15*Math.cos(angle_to_player), @y+15*Math.sin(angle_to_player), 3, 2*Math.cos(angle_to_player), 2*Math.sin(angle_to_player), 0, 255, 0),
    ) if (@age-@fire_delay) % @fire_rate == 0 && (@age-@fire_delay) >= 0
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
      # case (4 * (@t % (Math::PI * 2)) / (Math::PI) + 3) % 8
      # when 0.0..0.5
      #   @ship_sprite_angle = -90
      #   @ship_sprite_path = 'sprites/circle_enemy_thrust2.png'
      # when 0.5..2.5
      #   @ship_sprite_angle = 0
      #   @ship_sprite_path = 'sprites/circle_enemy_thrust2.png'
      # when 2.5..4.5
      #   @ship_sprite_angle = 180
      #   @ship_sprite_path = 'sprites/circle_enemy_thrust2.png'
      # when 4.5..6.5
      #   @ship_sprite_angle = 90
      #   @ship_sprite_path = 'sprites/circle_enemy_thrust2.png'
      # when 6.5..8.0
      #   @ship_sprite_angle = -90
      #   @ship_sprite_path = 'sprites/circle_enemy_thrust2.png'
      # else
      #   @ship_sprite_angle = 0
      #   @ship_sprite_path = 'sprites/circle_enemy.png'
      # end
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

  def renderable
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

  def renderable
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