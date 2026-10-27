#===============================================================================
# Planetarium - saved state ($PokemonGlobal.planet_quest). Leaf under PlanetRules.
#===============================================================================

class PokemonGlobalMetadata
  attr_writer :planet_quest

  def planet_quest
    @planet_quest = PlanetRules.normalize(@planet_quest)
    return @planet_quest
  end
end

module Planet
  def self.state
    return PlanetRules.new_state if !$PokemonGlobal
    return $PokemonGlobal.planet_quest
  end
end
