require 'patches/console.rb'
require 'patches/console_prompt.rb'
require 'patches/framerate_diagnostics.rb'
require 'lib/geo_geo.rb'
require 'lib/shmup_lib.rb'
require 'app/common.rb'
require 'app/bullets.rb'
require 'app/enemies.rb'
require 'app/scenes.rb'

SceneDeck = [
    [LemniWave, []],
    [DelayScene, [60 * 2]],
    [SwarmWave, []],
    [BossCurtainOpen, []],
    [Boss1Scene, []],
    [BossCurtainClose, []],
]

# @param [GTK::Args] args
# @return [
# nil]
def tick(args)
  # Reset/initialization logic
  args.state.populated = false if args.inputs.keyboard.key_down.r
  init(args) unless args.state.populated

  # Background rendering
  args.outputs.background_color = [0, 0, 0]
  args.outputs.sprites << args.state.stars.do_tick

  # Scene logic
  if args.state.scene.completed?
    args.state.prev_scene = args.state.scene || InitScene.new(args.state.cm, args.state.player)
    scene_class, scene_args = args.state.scene_deck.shift
    if scene_args.empty?
      args.state.scene = scene_class.new(args.state.cm, args.state.player, args.state.prev_scene)
    else
      args.state.scene = scene_class.new(args.state.cm, args.state.player, args.state.prev_scene, *scene_args)
    end
    args.state.scene_deck = [*SceneDeck].map { |klass, klargs| [klass, [*klargs]] } if args.state.scene_deck.empty?
    args.state.player.scoring_data[:full_combo] = true
  end
  st_out = args.state.scene.do_tick(args)
  args.outputs.primitives << args.state.scene.renderables
  if st_out[:game_over]
    args.state.populated = false
    return
  end
  GeoGeo.tests_this_tick = 0 if Kernel.global_tick_count != GeoGeo.current_tick
  brute_pairs = args.state.cm.get_group(:enemies).length * args.state.cm.get_group(:player_bullets).length + args.state.cm.get_group(:enemy_bullets).length
  $all_brute_pairs += args.state.cm.get_group(:enemies).length * args.state.cm.get_group(:player_bullets).length + args.state.cm.get_group(:enemy_bullets).length
  $all_actual_tests += GeoGeo.tests_this_tick

  args.outputs.labels << [{x: 10, y: 10.from_top, text: "Score : #{args.state.player.score}", r: 255, g: 0, b: 0},
                          {x: 10, y: 40.from_top, text: "Combo : #{args.state.player.scoring_data[:combo] * (args.state.player.scoring_data[:full_combo] ? 10 : 1)}x", r: 255, g: 0, b: 0},
                          {x: 1205, y: 40, text: "Move:  WASD", r: 255, g: 0, b: 0, size_enum: -4},
                          {x: 1205, y: 20, text: "Fire: Space", r: 255, g: 0, b: 0, size_enum: -4}]

  # Debug labels
  texts = [
      "FPS: #{$gtk.current_framerate.to_s.to_i}",
      "Enemies: #{args.state.cm.get_group(:enemies).length}",
      "Avg Pairs/Tests: #{$all_actual_tests == 0 ? '∞' : ($all_brute_pairs / $all_actual_tests).round}",
      "Pairs/Tests    : #{GeoGeo.tests_this_tick == 0 ? '∞' : (brute_pairs / GeoGeo.tests_this_tick).round}",
      "Collision Tests: #{GeoGeo.tests_this_tick}",
      "Collision Pairs: #{brute_pairs}",
      "Scene: #{args.state.scene.class.name}",
  ]
  args.outputs.debug << texts.each_with_index.map do |text, idx|
    {x: 10, y: 20 * (idx + 1), text: text, r: 255, g: 0, b: 0, size_enum: -4}
  end
end

def init(args)
  $all_brute_pairs = 0
  $all_actual_tests = 0
  args.state.stars = StarField.new
  args.state.player = Player.new
  args.state.cm = ShmupLib::CollisionManager.new
  args.state.scene_deck = [*SceneDeck].map { |klass, klargs| [klass, [*klargs]] }
  scene_class, scene_args = args.state.scene_deck.shift
  args.state.prev_scene = InitScene.new(args.state.cm, args.state.player)
  args.state.scene = scene_class.new(args.state.cm, args.state.player, args.state.prev_scene, *scene_args)
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
    self
  end

  # @return [Symbol]
  def primitive_marker
    :sprite
  end

  def inspect
    #FIXME: This is just to placate DRGTK.
    self.class.name
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
  attr_accessor :collider, :x, :y, :hurt_box, :score, :scoring_data, :max_speed, :allow_player_control

  def initialize
    @x = 640
    @y = 64
    @collider = GeoGeo::Polygon.new([[-16, -16], [0, 16], [16, -16]])
    # @hurt_box = GeoGeo::Box.new_drgtk(@x - 2, @y - 2, 4, 4) # Very forgiving, but rather confusing. (If the user doesn't understand grazing, they might think collision detection is just busted)
    @hurt_box = GeoGeo::Polygon.new([[-15, -15], [0, 15], [15, -15]]) # Unforgiving, but more intuitive
    @collider.set_center([@x, @y])
    @hurt_box.set_center([@x, @y])
    @cur_fire_cooldown = 0
    @max_fire_cooldown = 10
    @ripple_barrel_left = true
    @score = 0
    @scoring_data = {
        combo: 1,
        full_combo: true
    }
    @max_speed = 3
    @allow_player_control = true
  end

  # @return [nil]
  # @param [Hash] params
  def update_score(params = {})
    if params[:combo_breaker]
      @scoring_data[:full_combo] = false
      @scoring_data[:combo] = 1
    end
    @score += (params[:score_inc] || 0) * @scoring_data[:combo] * (@scoring_data[:full_combo] ? 10 : 1)
    @scoring_data[:combo] += params[:combo_inc] || 0
  end

  # @param [GTK::Args] args
  # @param [ShmupLib::CollisionManager] cm
  # @return [nil]
  def do_tick(args, cm)
    # @type [Array] keys_dh
    keys_dh = args.inputs.keyboard.key[:down_or_held]
    dx, dy = 0, 0
    if @allow_player_control
      dx += 1 if keys_dh.include?(:d)
      dx -= 1 if keys_dh.include?(:a)
      dy += 1 if keys_dh.include?(:w)
      dy -= 1 if keys_dh.include?(:s)
    end
    if dx != 0 || dy != 0
      speed_factor = @max_speed / Math.sqrt(dx * dx + dy * dy)
      dx *= speed_factor
      dy *= speed_factor
    end
    dy = 716 - @collider.top if @collider.top >= 716 && dy >= 0
    dy = 4 - @collider.bottom if @collider.bottom <= 4 && dy <= 0
    half_sw = args.state.scene.area_width / 2
    dx = 636 + half_sw - @collider.right if @collider.right >= 636 + half_sw - dx && dx >= 0
    dx = 644 - half_sw - @collider.left if @collider.left <= 644 - half_sw - dx && dx <= 0

    shift(dx, dy) if dx != 0 || dy != 0
    if args.inputs.mouse.button_left || keys_dh.include?(:space)
      fire(cm, :ripple, dx * 0.1, 0)
    elsif args.inputs.mouse.button_right
      fire(cm, :salvo, dx * 0.1, 0)
    end
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
  def inspect
    #FIXME: This is just to placate DRGTK.
    self.class.name
  end
end