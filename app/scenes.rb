class AbstractScene
  def initialize

  end

  def do_tick(cm, player) end

  def renderables

  end
end

class LemniPeek < AbstractScene
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
    @area_width = 540
    @cm = cm
    @player = player
  end

  # @return [Hash]
  def build_spawn_table
    table = {}
    speed_div = 198
    spawn_rate = 36
    # Good values for speed_div and spawn_rate satisfy the following equation: (2*speed_div/spawn_rate) % 2 == 1
    count = 2 * speed_div / spawn_rate
    i = 1
    while i <= count
      table[spawn_rate * i] = [[EnemyLemni, [Math::PI / speed_div, 300, 200, 100]]]
      i += 1
    end
    table
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
      arr[i].move
      if arr[i].y > 730
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
      arr[i].move
      if arr[i].y < -10
        @cm.del_from_group(:enemy_bullets, arr[i])
        i -= 1
        il -= 1
      end
      i += 1
    end
  end

  def cm_tick
    enemy_pb_collisions = @cm.find_all_collisions_between(:enemies, :player_bullets)
    unless enemy_pb_collisions.empty?
      enemy_pb_collisions.each do
        # @type [AbstractEnemy] enemy
        # @type [Array<AbstractBullet>] bullets
      |enemy, bullets|
        enemy.health -= bullets.length
        if enemy.health <= 0
          cm.del_from_group(:enemies, enemy)
        end
        bullets.each { |b| cm.del_from_group(:player_bullets, b) }
      end
    end
    if cm.any_collision_between?(:players, :enemy_bullets)
      $gtk.reset
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
    # render order for this scene, back to front
    # Player
    # Enemies
    # Player bullets
    # Enemy bullets
    # Side panels
    [
        @player.renderable,
        @cm.get_group(:enemies).map(&:renderables),
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