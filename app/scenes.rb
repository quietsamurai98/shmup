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
  def initialize(cm, player)
    @scene_tick = -1 # Negative one, since we want the first tick to be tick zero.
    @spawn_table = build_spawn_table #spawn_tick => [[enemy1_class, [enemy1_initialization_args]],[enemy2_class, [enemy2_initialization_args]], ...]
    @area_width = 540 # 3:4 aspect ratio, like old-school vertical shooters.
    @cm = cm # The collision manager
    @player = player # The player
    @first_spawn_tick = @spawn_table.keys.min
  end

  # @return [Boolean] True if the game can move on to the next scene.
  def completed?
    @cm.get_group(:enemies).length == 0 && @first_spawn_tick < @scene_tick
  end

  # @return [Hash]
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

  def do_tick(args)
    @scene_tick += 1
    spawn_enemy if @spawn_table.has_key?(@scene_tick)

    # tick order:
    # player bullets
    tick_player_bullets
    # enemy bullets
    tick_enemy_bullets
    # collision manager
    cm_tick
    # player
    @player.do_tick(args, @cm)
    # enemies
    tick_enemies
  end

  # @return [nil]
  def tick_player_bullets
    arr = @cm.get_group(:player_bullets)
    i = 0
    il = arr.length
    while i < il
      ai = arr[i]
      ai.move
      if ai.y < -10 || ai.y > 730 || ai.x < 630 - @area_width / 2 || ai.x > 650 + @area_width / 2
        @cm.del_from_group(:player_bullets, arr[i])
        i -= 1
        il -= 1
      end
      i += 1
    end
  end

  # @return [nil]
  def tick_enemy_bullets
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

  def cm_tick
    enemy_pb_collisions = @cm.first_collision_between(:enemies, :player_bullets)
    # Why `first_collision_between` rather than `find_all_collisions_between` or `first_collisions_between`?
    # Doesn't that mean if two different enemies are hit by a player's bullet, only one would be killed on that tick?
    #
    # Yes. However, it isn't as big an issue as you'd think.
    # The likelihood of two different enemies being hit by two different bullets on the same frame is quite small.
    # Even if it does happen, the collision would be detected on the next tick.
    #
    # Now, what if we used one of the other methods?
    # - One bullet could kill many overlapping enemies. While this could actually be a neat mechanic, it isn't intended for normal bullets (yet).
    # - When there are many enemies and many bullets, it would be more expensive to check.

    unless enemy_pb_collisions.empty?
      enemy_pb_collisions.each do
        # @type [AbstractEnemy] enemy
        # @type [Array<AbstractBullet>] bullets
      |enemy, bullets|
        bullets.each { |b| enemy.health -= b.damage }

        if enemy.health <= 0
          cm.del_from_group(:enemies, enemy)
        end
        bullets.each { |b| cm.del_from_group(:player_bullets, b) }
      end
    end
    if cm.any_collision_between?(:enemy_bullets, :players)
      # $state.populated = false
    end
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
            {x: 0, y: 0, w: (1280 - @area_width) / 2, h: 720, r: 25, g: 0, b: 0, a: 255}.solid,
            {x: @area_width + (1280 - @area_width) / 2, y: 0, w: (1280 - @area_width) / 2, h: 720, r: 25, g: 0, b: 0, a: 255}.solid,
        ],
    ]
  end

  def spawn_enemy
    @spawn_table[@scene_tick].each do |st_row|
      @cm.add_to_group(:enemies, st_row[0].new(*st_row[1]))
    end
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
    spawn_rate = 8
    # Good values for speed_div and spawn_rate satisfy the following equation: (2*speed_div/spawn_rate) % 2 == 1
    count = 2 * speed_div / spawn_rate
    i = 1
    while i <= count
      table[spawn_rate * i] = [[EnemyLemni, [Math::PI / speed_div, 300, 200, 100, 640, 500, Math::PI * 2 * rand, 60 * 5.2, spawn_rate * (count - i + 5)]]]
      table[spawn_rate * i + spawn_rate / 2] = [[EnemyLemni, [Math::PI / speed_div, -300, -200, -100, 640, 500, Math::PI * 2 * rand, 60 * 5.2, spawn_rate * (count - i + 5) + 60 * 5.2 / 2]]]
      i += 1
    end
    table
  end
end

class DelayScene < GenericScene
  # @param [ShmupLib::CollisionManager] cm
  # @param [Player] player
  # @param [Integer] delay
  def initialize(cm, player, delay)
    @scene_tick = -1 # Negative one, since we want the first tick to be tick zero.
    @spawn_table = {}
    @area_width = 540 # 3:4 aspect ratio, like old-school vertical shooters.
    @cm = cm # The collision manager
    @player = player # The player
    @first_spawn_tick = delay
  end
end