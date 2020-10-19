require 'patches/core.rb'
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
def tock(args)
  args.state.foo ||= BossLaserTurret.new(640 - 480, 720 - 64)
  args.state.bar ||= BossLaserTurret.new(640 + 480, 720 - 64)
  init(args) unless args.state.populated
  args.state.foo.do_tick(args.state.cm, args.state.player)
  args.state.bar.do_tick(args.state.cm, args.state.player)
  args.state.player.do_tick(args, args.state.cm)
  args.outputs.primitives << {x: 40, y: 720 - 128, w: 1200, h: 128, path: "sprites/boss.png"}.sprite
  args.outputs.primitives << args.state.foo.renderables
  args.outputs.primitives << args.state.bar.renderables
  args.outputs.primitives << args.state.player
  args.outputs.background_color = [0, 0, 0]
end


SceneDeck = [
    [DelayScene, [60 * 2]],
    [LemniWave, []],
    [DelayScene, [60 * 2]],
    [SwarmWave, []],
]
# @param [GTK::Args] args
# @return [nil]
def tick(args)
  # Reset/initialization logic
  args.state.populated = nil if args.inputs.keyboard.key_down.r
  init(args) if args.state.populated == nil

  args.inputs.keyboard.key_down.q = true

  # Background rendering
  args.outputs.background_color = [0, 0, 0]
  args.state.stars.do_tick
  args.outputs.sprites << args.state.stars

  # Scene logic
  if args.state.scene.completed?
    scene_class, scene_args = args.state.scene_deck.shift
    if scene_args.empty?
      args.state.scene = scene_class.new(args.state.cm, args.state.player)
    else
      args.state.scene = scene_class.new(args.state.cm, args.state.player, *scene_args)
    end
    args.state.scene_deck = [*SceneDeck].map { |klass, klargs| [klass, [*klargs]] } if args.state.scene_deck.empty?
    args.state.player.scoring_data[:full_combo] = true
  end
  st_out = args.state.scene.do_tick(args)
  args.outputs.primitives << args.state.scene.renderables
  if st_out[:game_over]
    args.state.populated = nil
    return
  end

  GeoGeo.tests_this_tick = 0 if Kernel.global_tick_count != GeoGeo.current_tick
  brute_pairs += args.state.cm.get_group(:enemies).length * args.state.cm.get_group(:player_bullets).length + args.state.cm.get_group(:enemy_bullets).length
  $all_brute_pairs += args.state.cm.get_group(:enemies).length * args.state.cm.get_group(:player_bullets).length + args.state.cm.get_group(:enemy_bullets).length
  $all_actual_tests += GeoGeo.tests_this_tick

  args.outputs.labels << {x: 10, y: 10.from_top, text: "Score : #{args.state.player.score}", r: 255, g: 0, b: 0}
  args.outputs.labels << {x: 10, y: 40.from_top, text: "Combo : #{args.state.player.scoring_data[:combo] * (args.state.player.scoring_data[:full_combo] ? 10 : 1)}x", r: 255, g: 0, b: 0}

  # Debug labels
  args.outputs.debug << {x: 10, y: 210, text: "Current Scene   : #{args.state.scene.class.name}", r: 255, g: 0, b: 0}
  args.outputs.debug << {x: 10, y: 180, text: "Collision Pairs : #{brute_pairs}", r: 255, g: 0, b: 0}
  args.outputs.debug << {x: 10, y: 150, text: "Collision Tests : #{GeoGeo.tests_this_tick}", r: 255, g: 0, b: 0}
  args.outputs.debug << {x: 10, y: 120, text: "Pairs/Tests     : #{GeoGeo.tests_this_tick == 0 ? '∞' : (brute_pairs / GeoGeo.tests_this_tick).round}", r: 255, g: 0, b: 0}
  args.outputs.debug << {x: 10, y: 90, text:  "Avg Pairs/Tests : #{$all_actual_tests == 0 ? '∞' : ($all_brute_pairs / $all_actual_tests).round}", r: 255, g: 0, b: 0}
  args.outputs.debug << {x: 10, y: 60, text:  "Enemies : #{args.state.cm.get_group(:enemies).length}", r: 255, g: 0, b: 0}
  args.outputs.labels << {x: 10, y: 30, text: "FPS : #{$gtk.current_framerate.to_s.to_i}", r: 255, g: 0, b: 0}
end

def init(args)
  $all_brute_pairs = 0
  $all_actual_tests = 0
  args.state.stars = StarField.new
  args.state.player = Player.new
  args.state.cm = ShmupLib::CollisionManager.new
  args.state.scene_deck = [*SceneDeck].map { |klass, klargs| [klass, [*klargs]] }
  scene_class, scene_args = args.state.scene_deck.shift
  args.state.scene = scene_class.new(args.state.cm, args.state.player, *scene_args)
  args.state.cm.add_group(:players)
  args.state.cm.add_group(:enemies)
  args.state.cm.add_group(:player_bullets)
  args.state.cm.add_group(:enemy_bullets)
  args.state.cm.add_to_group(:players, args.state.player)
  args.state.populated = true
end

class StarField
  def initialize
    @y1 = (rand * -720).to_i
    @y2 = (rand * -720).to_i
    @y3 = (rand * -720).to_i
    @y4 = (rand * -720).to_i
  end

  def do_tick
    @y1 = (@y1 - 1 / 5) % -720
    @y2 = (@y2 - 1 / 4) % -720
    @y3 = (@y3 - 1 / 3) % -720
    @y4 = (@y4 - 1 / 2) % -720
  end

  # Instead of mucking around with doing `array.map(&:renderables)`, just... make the object renderable.

  # @return [Symbol]
  def primitive_marker
    :sprite
  end

  # @return [nil]
  # @param [FFI::Draw] ffi_draw
  def draw_override(ffi_draw)
    ffi_draw.draw_sprite(0, @y1, 1280, 1440, "sprites/starfield_1.png")
    ffi_draw.draw_sprite(0, @y2, 1280, 1440, "sprites/starfield_2.png")
    ffi_draw.draw_sprite(0, @y3, 1280, 1440, "sprites/starfield_3.png")
    ffi_draw.draw_sprite(0, @y4, 1280, 1440, "sprites/starfield_4.png")
  end
end

class Player
  attr_accessor :collider, :x, :y, :hurt_box, :score, :scoring_data

  def initialize
    @x = 640
    @y = 64
    @collider = GeoGeo::Polygon.new([[-16, -16], [0, 16], [16, -16]])
    @hurt_box = GeoGeo::Box.new_drgtk(@x-2, @y-2, 4, 4)
    @collider.set_center([@x, @y])
    @cur_fire_cooldown = 0
    @max_fire_cooldown = 10
    @ripple_barrel_left = true
    @score = 0
    @scoring_data = {
        combo: 1,
        full_combo: true
    }
  end

  # @return [nil]
  # @param [Hash] params
  def update_score(params = {})
    @scoring_data[:combo] += params[:combo_inc] || 0
    if params[:combo_breaker]
      @scoring_data[:full_combo] = false
      @scoring_data[:combo] = 1
    end
    @score += (params[:score_inc] || 0) * @scoring_data[:combo] * (@scoring_data[:full_combo] ? 10 : 1)
  end

  # @param [GTK::Args] args
  # @param [ShmupLib::CollisionManager] cm
  # @return [nil]
  def do_tick(args, cm)
    # @type [Array] keys_dh
    keys_dh = args.inputs.keyboard.key[:down_or_held]
    dx, dy = 0, 0
    dx += 1 if keys_dh.include?(:d)
    dx -= 1 if keys_dh.include?(:a)
    dy += 1 if keys_dh.include?(:w)
    dy -= 1 if keys_dh.include?(:s)
    if dx != 0 || dy != 0
      speed_factor = 3 / Math.sqrt(dx * dx + dy * dy)
      dx *= speed_factor
      dy *= speed_factor
    end
    shift(dx, dy) if dx != 0 || dy != 0
    fire(cm, :ripple, dx * 0.1, 0) if args.inputs.mouse.button_left
    fire(cm, :salvo, dx * 0.1, 0) if args.inputs.mouse.button_right && !args.inputs.mouse.button_left
    @cur_fire_cooldown -= 1 if @cur_fire_cooldown > 0
  end

  # @param [Integral] dx
  # @param [Integral] dy
  # @return [nil]
  def shift(dx, dy)
    @x += dx
    @y += dy
    @collider.shift(dx, dy)
    @hurt_box.shift(dx, dy)
  end

  # @param [ShmupLib::CollisionManager] cm
  # @param [Symbol] mode
  # @return [nil]
  def fire(cm, mode, dx, dy)
    if @cur_fire_cooldown == 0
      if mode == :ripple
        ripple_fire(cm, dx, dy)
        @cur_fire_cooldown = @max_fire_cooldown
      end
      if mode == :salvo
        salvo_fire(cm, dx, dy)
        @cur_fire_cooldown = @max_fire_cooldown + @max_fire_cooldown
      end
    end
  end

  # @param [ShmupLib::CollisionManager] cm
  def ripple_fire(cm, dx, dy)
    if @ripple_barrel_left
      cm.add_to_group(:player_bullets, SimpleBoxBullet.new(@x - 8, @y - 1, 4, 4, 0 + dx, 4 + dy))
    else
      cm.add_to_group(:player_bullets, SimpleBoxBullet.new(@x + 4, @y - 1, 4, 4, 0 + dx, 4 + dy))
    end
    @ripple_barrel_left = !@ripple_barrel_left
  end

  # @param [ShmupLib::CollisionManager] cm
  def salvo_fire(cm, dx, dy)
    cm.add_to_group(:player_bullets, SimpleBoxBullet.new(@x - 8, @y - 1, 4, 4, 0 + dx, 3 + dy))
    cm.add_to_group(:player_bullets, SimpleBoxBullet.new(@x + 4, @y - 1, 4, 4, 0 + dx, 3 + dy))
  end

  # Instead of mucking around with doing `array.map(&:renderables)`, just... make the object renderable.

  # @return [Symbol]
  def primitive_marker
    :sprite
  end

  # @return [nil]
  # @param [FFI::Draw] ffi_draw
  def draw_override(ffi_draw)
    ffi_draw.draw_sprite_2(@x - 16, @y - 16, 32, 32, "sprites/player.png", nil, nil)
    if false
      @collider.verts.each_cons(2).map do
        # @type [Array] a
        # @type [Array] b
      |a, b|
        ffi_draw.draw_line(a.x, a.y, b.x, b.y, 0, 255, 0, 255)
      end
    end
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