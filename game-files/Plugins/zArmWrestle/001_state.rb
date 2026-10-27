#===============================================================================
# Arm wrestling - saved per-run state ($PokemonGlobal.arm_wrestle); a new game starts fresh.
#===============================================================================

class PokemonGlobalMetadata
  attr_writer :arm_wrestle

  def arm_wrestle
    @arm_wrestle = ArmWrestleRules.normalize(@arm_wrestle)
    return @arm_wrestle
  end
end

module ArmWrestle
  def self.state
    return ArmWrestleRules.new_state if !$PokemonGlobal
    return $PokemonGlobal.arm_wrestle
  end
end
