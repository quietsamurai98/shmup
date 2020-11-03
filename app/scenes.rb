class GenericScene
  # This class contains the basic logic needed for most "spawn a wave of enemies" type scenes.
  # Specific scenes should use this as a superclass, and override logic as needed.

  # @return [Integer]
  attr_accessor :scene_tick, :area_width
  # @return [Hash<Array<Class,Array>>]
  attr_accessor :spawn_table
  # @return [ShmupLib::CollisionManager]
  attr_accessor :cm
  # @return [Player]
  attr_accessor :player

  # @param [ShmupLib::CollisionManager] cm
  # @param [Player] player
  # @param [GenericScene, nil] last_scene
  # @return [nil]
  def initialize(cm, player, last_scene)
    @scene_tick = -1 # Negative one, since we want the first tick to be tick zero.
    _spawn_table = build_spawn_table
    @spawn_table = _spawn_table #spawn_tick => [[enemy1_class, [enemy1_initialization_args]],[enemy2_class, [enemy2_initialization_args]], ...]
    @area_width = last_scene&.area_width || 540 # Use the last scene's width, falling back to a 3:4 aspect ratio, like old-school vertical shooters.
    @cm = cm # The collision manager
    @player = player # The player
    @first_spawn_tick = _spawn_table.keys.min
  end

  # @return [Boolean] True if the game can move on to the next scene.
  def completed?
    @cm.get_group(:enemies).length == 0 && @first_spawn_tick < @scene_tick
  end

  # @return [Hash<Array<Class,Array>>]
  def build_spawn_table
    table = {}
    # Here is where you'd build your spawn table.
    # A spawn table uses scene ticks for keys, and arrays of spawn data for the values
    # Spawn data is an array with the enemy class to spawn as the first element,
    # and an array of the args taken by the class's constructor as the second element.

    # Example:
    table[0] = [AbstractEnemy, [640, 720 - 100]]

    # This would spawn an AbstractEnemy on tick zero, creating the enemy by calling AbstractEnemy.new(640, 720-100)

    return table
  end

  # @return [Hash]
  # @param [GTK::Args] args
  def do_tick(args)
    @scene_tick += 1
    spawn_enemy if @spawn_table.has_key?(@scene_tick)

    # tick order:
    # player bullets
    tick_player_bullets
    # enemy bullets
    tick_enemy_bullets
    # collision manager
    cm_out = cm_tick
    # player
    @player.do_tick(args, @cm)
    # enemies
    tick_enemies

    if cm_out[:game_over]
      return {game_over: true}
    end
    return {}
  end

  # @return [nil]
  def tick_player_bullets
    # @type [Array<AbstractBullet>] arr
    arr = @cm.get_group(:player_bullets)
    i = 0
    il = arr.length
    while i < il
      ai = arr[i]
      ai.move
      if ai.y < -10 || ai.y > 730 || ai.x < 630 - @area_width / 2 || ai.x > 650 + @area_width / 2
        @cm.del_from_group(:player_bullets, arr[i])
        @player.update_score({combo_breaker: true})
        i -= 1
        il -= 1
      end
      i += 1
    end
  end

  # @return [nil]
  def tick_enemy_bullets
    # @type [Array<AbstractBullet>] arr
    arr = @cm.get_group(:enemy_bullets)
    i = 0
    il = arr.length
    while i < il
      ai = arr[i]
      ai.move
      if ai.y < -10 || ai.y > 730 || ai.x < 630 - @area_width / 2 || ai.x > 650 + @area_width / 2
        @cm.del_from_group(:enemy_bullets, ai)
        i -= 1
        il -= 1
      end
      i += 1
    end
  end

  # @return [Hash]
  def cm_tick
    @cm.get_group(:enemies)
    @cm.get_group(:player_bullets)
    enemy_pb_collisions = @cm.first_collisions_between(:enemies, :player_bullets)

    unless enemy_pb_collisions.empty?
      enemy_pb_collisions.each do
        # @type [AbstractEnemy] enemy
        # @type [Array<AbstractBullet>] bullets
      |enemy, bullets|
        bullets.each do |b|
          if cm.del_from_group(:player_bullets, b)
            enemy.health -= b.damage
            if enemy.health <= 0
              cm.del_from_group(:enemies, enemy)
              @player.update_score({score_inc: 1, combo_inc: 1})
              break
            else
              @player.update_score({combo_inc: 1})
            end
          end
        end
      end
    end
    cm.find_all_collisions_between(:players, :enemy_bullets).each do
      # @type [Player] player
      # @type [Array<AbstractBullet>] bullets
    |player, bullets|
      if bullets.any? do
        # @type [AbstractBullet] b
      |b|
        GeoGeo::intersect?(player.hurt_box, b.collider)
      end
        return {game_over: true}
      else
        # 1*combo points per grazing bullet, per tick.
        player.update_score({score_inc: 1})
      end
    end
    return {game_over: false}
  end

  # @return [nil]
  def tick_enemies
    # @type [Array<AbstractEnemy>] arr
    arr = @cm.get_group(:enemies)
    i = 0
    l = arr.length
    while i < l
      arr[i].do_tick(@cm, @player)
      i += 1
    end
  end

  # @return [Array]
  def renderables
    # Render order for this scene, back to front
    # Player
    # Enemies
    # Player bullets
    # Enemy bullets
    # Side panels
    [
        @player,
        @cm.get_group(:enemies),
        @cm.get_group(:player_bullets),
        @cm.get_group(:enemy_bullets),
        [
            {x: -1, y: 0, w: ((1280 - @area_width) / 2) + 1, h: 721, r: 50, g: 0, b: 0, a: 255}.solid,
            {x: (1280 + @area_width) / 2, y: 0, w: (1280 - @area_width) / 2, h: 721, r: 50, g: 0, b: 0, a: 255}.solid,
        ],
    ]
  end

  # @return [nil]
  def spawn_enemy
    @spawn_table[@scene_tick].each do |st_row|
      @cm.add_to_group(:enemies, st_row[0].new(*st_row[1]))
    end
  end

  def inspect
    #FIXME: This is just to placate DRGTK.
    self.class.name
  end
end

class LemniWave < GenericScene

  # @return [Hash]
  def build_spawn_table
    table = {}
    speed_div = 198
    spawn_rate = 36
    # Good values for speed_div and spawn_rate satisfy the following equation: (2*speed_div/spawn_rate) % 2 == 1
    count = 2 * speed_div / spawn_rate
    i = 1
    while i <= count
      table[spawn_rate * i] = [[EnemyLemni, [Math::PI / speed_div, 300, 200, 100, 640, 500, 0, 60 * 5.2, spawn_rate * (count - i + 1)]]]
      i += 1
    end
    table
  end
end

class SwarmWave < GenericScene
  # @return [Hash]
  def build_spawn_table
    table = {}
    speed_div = 200
    spawn_rate = 32
    # Good values for speed_div and spawn_rate satisfy the following equation: (2*speed_div/spawn_rate) % 2 == 1
    count = 2 * speed_div / spawn_rate
    fire_delay = 60 * 12
    i = 1
    while i <= count
      table[spawn_rate * i] = [[EnemyLemni, [Math::PI / speed_div, 300, 200, 100, 640, 500, Math::PI * 2 * rand, fire_delay, spawn_rate * (count - i + 5)]]]
      table[spawn_rate * i + spawn_rate / 2] = [[EnemyLemni, [Math::PI / speed_div, -300, -200, -100, 640, 500, Math::PI * 2 * rand, fire_delay, spawn_rate * (count - i + 5) + fire_delay / 2]]]
      i += 1
    end
    table
  end
end

class BossLemni < GenericScene
  # @param [ShmupLib::CollisionManager] cm
  # @param [Player] player
  # @param [GenericScene, nil] last_scene
  # @return [nil]
  def initialize(cm, player, last_scene)
    super(cm, player, last_scene)
  end

  # @return [Hash]
  def build_spawn_table
    table = {}
    speed_div = 400
    spawn_rate = 16
    # Good values for speed_div and spawn_rate satisfy the following equation: (2*speed_div/spawn_rate) % 2 == 1
    count = 2 * speed_div / spawn_rate
    fire_delay = 60 * 12
    i = 1
    while i <= count
      table[spawn_rate * i] = [[EnemyLemni, [Math::PI / speed_div, 512, 448, 200, 640, 480, Math::PI * 2 * rand, fire_delay, spawn_rate * (count - i + 5)]]]
      table[spawn_rate * i + spawn_rate / 4] = [[EnemyLemni, [Math::PI / speed_div, -512, -448, 200, 640, 480, Math::PI * 2 * rand, fire_delay, spawn_rate * (count - i + 5)]]]
      table[spawn_rate * i + spawn_rate / 2] = [[EnemyLemni, [Math::PI / speed_div, -512, -448, -200, 640, 480, Math::PI * 2 * rand, fire_delay, spawn_rate * (count - i + 5) + fire_delay / 2]]]
      table[spawn_rate * i + 3 * spawn_rate / 4] = [[EnemyLemni, [Math::PI / speed_div, 512, 448, -200, 640, 480, Math::PI * 2 * rand, fire_delay, spawn_rate * (count - i + 5) + 3 * fire_delay / 2]]]
      i += 1
    end
    table
  end
end

class DelayScene < GenericScene
  # @param [ShmupLib::CollisionManager] cm
  # @param [Player] player
  # @param [GenericScene, nil] last_scene
  # @param [Integer] delay
  # @return [nil]
  def initialize(cm, player, last_scene, delay)
    @scene_tick = -1 # Negative one, since we want the first tick to be tick zero.
    @spawn_table = {}
    @area_width = last_scene&.area_width || 540 # Keep the area width of the previous scene, or fall back to the default 540.
    @cm = cm # The collision manager
    @player = player # The player
    @first_spawn_tick = delay
  end
end

class InitScene < GenericScene
  # @param [ShmupLib::CollisionManager] cm
  # @param [Player] player
  # @return [nil]
  def initialize(cm, player)
    @scene_tick = -1 # Negative one, since we want the first tick to be tick zero.
    @spawn_table = {}
    @area_width = 540
    @cm = cm # The collision manager
    @player = player # The player
    @first_spawn_tick = -2
  end
end


class BossCurtainOpen < GenericScene
  # @param [ShmupLib::CollisionManager] cm
  # @param [Player] player
  # @param [GenericScene, nil] last_scene
  # @return [nil]
  def initialize(cm, player, last_scene)
    @scene_tick = -1 # Negative one, since we want the first tick to be tick zero.
    @spawn_table = {}
    @area_width = 540 # 3:4 aspect ratio, like old-school vertical shooters.
    @cm = cm # The collision manager
    @player = player # The player
    @first_spawn_tick = 210
  end

  # @return [Hash]
  # @param [GTK::Args] args
  def do_tick(args)
    @area_width -= 2
    super(args)
  end
end

class BossCurtainOpen < GenericScene
  # @param [ShmupLib::CollisionManager] cm
  # @param [Player] player
  # @param [GenericScene, nil] last_scene
  # @return [nil]
  def initialize(cm, player, last_scene)
    @scene_tick = -1 # Negative one, since we want the first tick to be tick zero.
    @spawn_table = {}
    @area_width = 540 # 4:3 aspect ratio, for boss fights.
    @cm = cm # The collision manager
    @player = player # The player
    @curtain_speed = 2
    @first_spawn_tick = (960 - 540) / @curtain_speed
  end

  # @return [Hash]
  # @param [GTK::Args] args
  def do_tick(args)
    if @cm.get_group(:enemy_bullets).length == 0
      @area_width += @curtain_speed
      @area_width = 960 if @area_width > 960
    end
    super(args)
  end

  # @return [Boolean]
  def completed?
    @area_width == 960
  end
end

class BossCurtainClose < GenericScene
  # @param [ShmupLib::CollisionManager] cm
  # @param [Player] player
  # @param [GenericScene, nil] last_scene
  # @return [nil]
  def initialize(cm, player, last_scene)
    @scene_tick = -1 # Negative one, since we want the first tick to be tick zero.
    @spawn_table = {}
    @area_width = 960 # 4:3 aspect ratio, for boss fights.
    @cm = cm # The collision manager
    @player = player # The player
    @curtain_speed = 3
    @first_spawn_tick = (960 - 540) / @curtain_speed
  end

  # @return [Hash]
  # @param [GTK::Args] args
  def do_tick(args)
    if @cm.get_group(:enemy_bullets).length == 0
      @area_width -= @curtain_speed
      @area_width = 540 if @area_width < 540
    end
    super(args)
  end

  # @return [Boolean]
  def completed?
    @area_width == 540
  end
end

class Boss1Scene < GenericScene
  def initialize(cm, player, last_scene)
    @boss = Boss1.new(640, 900, true)
    @player_health = 30
    super(cm,player,last_scene)
  end
  def do_tick(args)
    if @boss.y > 600
      @boss.y -= 0.5
      @cm.get_group(:enemies).each { |e| e.update_pos(0, -0.5) }
      @boss.update_pos
    end
    if @cm.get_group(:enemies).empty? && @boss.age > 10
      @boss.y += 5
      @boss.update_pos
    end
    @boss.age += 1
    last_player_x = @player.x
    last_player_y = @player.y
    out = super(args)
    if GeoGeo::intersect?(@player.collider, @boss.collider)
      @player.shift(last_player_x - @player.x, last_player_y - @player.y)
    end
    @cm.get_group(:enemies).each do |enemy|
      next unless enemy.instance_of?(BossLaserTurret)
      @player_health -= 1 if GeoGeo::intersect?(@player.hurt_box, enemy.beam_collider)
      out[:game_over] = true if @player_health < 0
    end
    out
  end
  def build_spawn_table
    table = {}
    table[0] = [
        [BossLaserTurret, [@boss.x + 142, @boss.y - 71]],
        [BossLaserTurret, [@boss.x - 142, @boss.y - 71]],
        [BossLaserTurret, [@boss.x + 277, @boss.y - 50]],
        [BossLaserTurret, [@boss.x - 277, @boss.y - 50]]
    ]
    table
  end
  def renderables
    [@boss, super]
  end
  # @return [Boolean] True if the game can move on to the next scene.
  def completed?
    false || @boss.y > 900;
  end
end