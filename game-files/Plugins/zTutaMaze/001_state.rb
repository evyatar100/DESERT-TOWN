#===============================================================================
# Tuta maze - saved per-run state ($PokemonGlobal.tuta_maze); old saves load the default.
#===============================================================================

class PokemonGlobalMetadata
  attr_writer :tuta_maze

  def tuta_maze
    @tuta_maze = TutaMazeRules.normalize(@tuta_maze)
    return @tuta_maze
  end
end

module TutaMaze
  # F9 "leave 1 strawberry": the next game starts with all but LAST_BERRY eaten (not saved).
  @leave_one = false

  class << self
    attr_accessor :leave_one
  end

  def self.state
    return TutaMazeRules.new_state if !$PokemonGlobal
    return $PokemonGlobal.tuta_maze
  end

  # Cells already eaten when a game starts (consumes the F9 flag).
  def self.preset_eaten
    return [] unless @leave_one
    @leave_one = false
    TutaMazeRules.berries - [TutaMazeRules::LAST_BERRY]
  end
end
