class AbstractScene
  def initialize

  end
  def do_tick

  end
end

class WideInvaders < AbstractScene
  def initialize
    @scene_tick = 0
    @spawn_table = {
        #spawn_tick => [[enemy1_class, [enemy1_initialization_args]],[enemy2_class, [enemy2_initialization_args]], ...]
    }
  end

  def do_tick

  end
end