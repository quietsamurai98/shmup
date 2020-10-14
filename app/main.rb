require 'patches/console.rb'
require 'patches/console_prompt.rb'
require 'patches/framerate_diagnostics.rb'
require 'lib/geo_geo.rb'
require 'lib/shmup_lib.rb'
require 'app/common.rb'
require 'app/bullets.rb'
require 'app/enemies.rb'
require 'app/scenes.rb'


# @param [GTK::Args] args
# @return [nil]
def tick(args)
  # Reset/initialization logic
  args.state.clear! if args.inputs.keyboard.key_down.r
  init(args) unless args.state.populated

  # Background rendering
  args.outputs.background_color = [0, 0, 0]
  args.state.stars.do_tick
  args.outputs.primitives << args.state.stars.renderables

  # Scene logic
  args.state.scene = LemniWave.new(args.state.cm, args.state.player) if args.state.scene.completed?
  args.state.scene.do_tick(args)
  args.outputs.primitives << args.state.scene.renderables

  # Debug labels
  args.outputs.labels << {x: 10, y: 30, text: "FPS : #{$gtk.current_framerate.to_s.to_i}", r: 255, g: 0, b: 0}
end

def init(args)
  args.state.stars = StarField.new
  args.state.player = Player.new
  args.state.cm = ShmupLib::CollisionManager.new
  args.state.scene = LemniWave.new(args.state.cm, args.state.player)
  args.state.cm.add_group(:players)
  args.state.cm.add_group(:enemies)
  args.state.cm.add_group(:player_bullets)
  args.state.cm.add_group(:enemy_bullets)
  args.state.cm.add_to_group(:players, args.state.player)
  args.state.populated = true
end

class StarField
  def initialize
    @layer1, @layer2, @layer3, @layer4 = [
        SpriteClass.new(x: 0, w: 1280, h: 1440, path: 'sprites/starfield_1.png', y: (rand * -720).to_i),
        SpriteClass.new(x: 0, w: 1280, h: 1440, path: 'sprites/starfield_2.png', y: (rand * -720).to_i),
        SpriteClass.new(x: 0, w: 1280, h: 1440, path: 'sprites/starfield_3.png', y: (rand * -720).to_i),
        SpriteClass.new(x: 0, w: 1280, h: 1440, path: 'sprites/starfield_4.png', y: (rand * -720).to_i)
    ].shuffle
  end

  def do_tick
    @layer1.y = (@layer1.y - 1 / 5) % -720
    @layer2.y = (@layer2.y - 1 / 4) % -720
    @layer3.y = (@layer3.y - 1 / 3) % -720
    @layer4.y = (@layer4.y - 1 / 2) % -720
  end

  def renderables
    [
        @layer1,
        @layer2,
        @layer3,
        @layer4,
    ]
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
  # @return [nil]
  def do_tick(args, cm)
    # @type [Array] keys_dh
    keys_dh = args.inputs.keyboard.key[:down_or_held]
    dx, dy = 0, 0
    dx += 3 if keys_dh.include?(:d)
    dx -= 3 if keys_dh.include?(:a)
    dy += 3 if keys_dh.include?(:w)
    dy -= 3 if keys_dh.include?(:s)
    shift(dx, dy) if dx != 0 || dy != 0
    fire(cm, :ripple, dx * 0.1, dy.abs) if args.inputs.mouse.button_left || keys_dh.include?(:q) && !keys_dh.include?(:e)
    fire(cm, :salvo, dx * 0.1, dy.abs) if keys_dh.include?(:e) && !keys_dh.include?(:q) && !args.inputs.mouse.button_left
    fire(cm, :volley, dx * 0.1, dy.abs) if keys_dh.include?(:q) && keys_dh.include?(:e) && !args.inputs.mouse.button_left
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
    cm.add_to_group(:player_bullets, SimpleBoxBullet.new(@x + bx, @y + by, 2, 3, 0 + dx, 3 + dy))
    @cur_barrel = (@cur_barrel + 1) % @num_barrel
  end

  # @param [ShmupLib::CollisionManager] cm
  def salvo_fire(cm, dx, dy)
    if @cur_barrel == 0
      cm.add_to_group(
          :player_bullets,
          SimpleBoxBullet.new(@x - 10, @y - 2, 2, 3, 0 + dx, 3+dy),
          SimpleBoxBullet.new(@x - 4, @y - 2, 2, 3, 0 + dx, 3+dy),
          SimpleBoxBullet.new(@x + 2, @y - 2, 2, 3, 0 + dx, 3+dy),
          SimpleBoxBullet.new(@x + 8, @y - 2, 2, 3, 0 + dx, 3+dy)
      )
    end
    @cur_barrel = (@cur_barrel + 1) % @num_barrel
  end

  # @param [ShmupLib::CollisionManager] cm
  def volley_fire(cm, dx, dy)
    if @cur_barrel == 0
      cm.add_to_group(:player_bullets, SimpleBoxBullet.new(@x - 10, @y - 2, 2, 3, 0 + dx, 3 + dy))
      cm.add_to_group(:player_bullets, SimpleBoxBullet.new(@x + 2, @y - 2, 2, 3, 0 + dx, 3 + dy))
    end
    if @cur_barrel == 2
      cm.add_to_group(:player_bullets, SimpleBoxBullet.new(@x - 4, @y - 2, 2, 3, 0 + dx, 3 + dy))
      cm.add_to_group(:player_bullets, SimpleBoxBullet.new(@x + 8, @y - 2, 2, 3, 0 + dx, 3 + dy))
    end
    @cur_barrel = (@cur_barrel + 1) % @num_barrel
  end

  # @return [Array]
  def renderables
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

# Here lies old, dead code.
# I'll rip a boss fight out of here soon.
#
# def old_tick(args)
#   args.gtk.hide_cursor
#   if args.inputs.keyboard.key_down.r || Kernel.tick_count == 0
#     $boss_y = 722
#     $boss_spawn = 0
#     args.state.area_width = 540
#     args.state.game_tick = -1
#     init(args)
#   end
#   args.state.game_tick += 1
#   # @type [ShmupLib::CollisionManager] cm
#   cm = args.state.cm
#   # @type [Player] player
#   player = args.state.player
#
#   if args.state.area_width < 1280 && (args.inputs.keyboard.key_held.z || args.state.area_width != 540)
#     if args.state.area_width == 540
#       # args.outputs.sounds << 'sounds/boss_alarm.wav'
#     end
#     args.state.area_width = args.state.area_width + 2.5
#   end
#   area_width = args.state.area_width
#   if area_width == 1280
#     if $boss_y > 720 - 128
#       $boss_y -= 1
#     end
#     if $boss_spawn < 25 && args.state.game_tick % 32 == 0 && $boss_y < 670
#       spawn_enemy(cm, :boss)
#       $boss_spawn += 1
#     end
#     args.outputs.primitives << {
#         x: 40,
#         y: $boss_y,
#         w: 1200,
#         h: 128,
#         path: 'sprites/boss.png'
#     }
#   end
#
#   # spawn_enemy(cm, :fig8) if args.state.game_tick % 37 == 0 && args.state.game_tick.between?(120, 120 + 37 * 17)
#
#   args.outputs.background_color = [0, 0, 0]
#
#   tick_player_bullets(cm)
#   tick_enemy_bullets(cm)
#
#   cm_tick(cm)
#
#   player.do_tick(args, cm)
#   tick_enemies(cm, player)
#
#   args.outputs.primitives << player.renderable
#   args.outputs.primitives << cm.get_group(:enemies).map(&:renderable)
#   args.outputs.primitives << cm.get_group(:enemy_bullets)
#   args.outputs.primitives << cm.get_group(:player_bullets)
#   args.outputs.primitives << {x: 0, y: 0, w: 640 - area_width / 2, h: 720, r: 25}.solid
#   args.outputs.primitives << {x: 640 + area_width / 2, y: 0, w: 640 - area_width / 2, h: 720, r: 25}.solid
#
#   args.outputs.static_solids.each do |s|
#     s.y = (s.y + 10 - s[:v]) % 740 - 10
#   end
#   args.outputs.labels << [
#       {x: 275 - area_width / 2, y: 30, text: "FPS : #{$gtk.current_framerate.to_s.to_i}", r: 255, g: 0, b: 0},
#       {x: 275 - area_width / 2, y: 60, text: "Possible Collision Pairs : #{cm.get_group(:enemies).length * cm.get_group(:player_bullets).length + cm.get_group(:enemy_bullets).length}", r: 255, g: 0, b: 0},
#       {x: 275 - area_width / 2, y: 90, text: "Player Bullet Count : #{cm.get_group(:player_bullets).length}", r: 255, g: 0, b: 0},
#       {x: 275 - area_width / 2, y: 120, text: "Enemy Bullet Count : #{cm.get_group(:enemy_bullets).length}", r: 255, g: 0, b: 0},
#       {x: 275 - area_width / 2, y: 150, text: "Enemy Count : #{cm.get_group(:enemies).length}", r: 255, g: 0, b: 0},
#   ]
# end
#
# # @param [ShmupLib::CollisionManager] cm
# def spawn_enemy(cm, sym)
#   if sym == :fig8
#     cm.add_to_group(:enemies, Figure8Enemy.new(0.01))
#   end
#   if sym == :boss
#     cm.add_to_group(:enemies, BossFigure8Enemy.new(Math::PI / 400))
#   end
# end
#
# # @param [ShmupLib::CollisionManager] cm
# def tick_enemies(cm, player)
#   arr = cm.get_group(:enemies)
#   i = 0
#   il = arr.length
#   while i < il
#     arr[i].do_tick(cm, player)
#     if false # TODO
#       cm.del_from_group(:enemies, arr[i])
#       i -= 1
#       il -= 1
#     end
#     i += 1
#   end
# end