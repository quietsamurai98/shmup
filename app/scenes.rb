class AbstractScene
  def initialize

  end
  def do_tick(cm, player)

  end
  def renderables

  end
end

class LemniPeek < AbstractScene
  def initialize(cm, player)
    @scene_tick = -1 # Negative one, since we want the first tick to be tick zero.
    @enemies = []
    @spawn_table = build_spawn_table #spawn_tick => [[enemy1_class, [enemy1_initialization_args]],[enemy2_class, [enemy2_initialization_args]], ...]
    @area_width = 540
    @cm = cm
    @player = player
  end

  def build_spawn_table
    table = {}
    speed_div = 198
    spawn_rate = 36
    # Good values for speed_div and spawn_rate satisfy the following equation: (2*speed_div/spawn_rate) % 2 == 1
    count = 2*speed_div/spawn_rate
    i = 1
    while i <= count
      table[spawn_rate*i] = [[EnemyLemni, [Math::PI/speed_div, 300, 200, 100]]]
      i+=1
    end
    table
  end

  def do_tick
    @scene_tick += 1
    spawn_enemy if @spawn_table.has_key?(@scene_tick)
    @enemies.each do |e|
      e.do_tick(@cm, @player)
    end
  end

  def renderables
    @enemies.each.flat_map(&:renderable).append(
        @player.renderable,
        {x:0, y: 0, w: (1280-@area_width)/2, h: 720, r: 25, g: 0, b: 0, a: 255}.solid,
        {x:@area_width + (1280-@area_width)/2, y: 0, w: (1280-@area_width)/2, h: 720, r: 25, g: 0, b: 0, a: 255}.solid,
    )
  end

  def spawn_enemy
    @spawn_table[@scene_tick].each do |st_row|
      @enemies << st_row[0].new(*st_row[1])
    end
  end
end