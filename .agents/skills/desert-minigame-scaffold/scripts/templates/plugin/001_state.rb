#===============================================================================
# __NAME__ - saved per-run state ($PokemonGlobal.__SNAKE__); old saves load the default.
#===============================================================================

class PokemonGlobalMetadata
  attr_writer :__SNAKE__

  def __SNAKE__
    @__SNAKE__ = __NAME__Rules.normalize(@__SNAKE__)
    return @__SNAKE__
  end
end

module __NAME__
  def self.state
    return __NAME__Rules.new_state if !$PokemonGlobal
    return $PokemonGlobal.__SNAKE__
  end
end
