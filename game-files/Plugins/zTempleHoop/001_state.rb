#===============================================================================
# Temple hoop - saved per-run state ($PokemonGlobal.temple_hoop). A new game makes
# a new PokemonGlobalMetadata, so Evyatar comes once per run.
#===============================================================================

class PokemonGlobalMetadata
  attr_writer :temple_hoop

  def temple_hoop
    @temple_hoop = TempleHoopRules.normalize(@temple_hoop)
    return @temple_hoop
  end
end

module TempleHoop
  def self.state
    return TempleHoopRules.new_state if !$PokemonGlobal
    return $PokemonGlobal.temple_hoop
  end
end
