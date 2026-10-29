#===============================================================================
# DesertScreens (TG57 Batch 4) - the circus fight only (MomDadBattle.active?):
# a plain wipe instead of the Rocket "R", War then DT Victory, the circus arena.
# Every other battle is untouched.
#===============================================================================

module DesertScreens
  def self.circus_active?
    return defined?(MomDadBattle) && MomDadBattle.active?
  end

  def self.circus_audio(name)
    return RPG::AudioFile.new(name, 80, 100)
  end

  def self.set_circus_music
    $PokemonGlobal.nextBattleBGM = circus_audio(CIRCUS_BGM)
    $PokemonGlobal.nextBattleVictoryBGM = circus_audio(CIRCUS_VICTORY_BGM)
  end

  def self.clear_circus_music
    $PokemonGlobal.nextBattleBGM = nil
    $PokemonGlobal.nextBattleVictoryBGM = nil
  end
end

SpecialBattleIntroAnimations.register(DesertScreens::CIRCUS_INTRO_NAME, DesertScreens::CIRCUS_INTRO_PRIORITY,
  proc { |battle_type, foe, location| next DesertScreens.circus_active? },
  proc { |viewport, battle_type, foe, location|
    pbBattleAnimationCore(DesertScreens::CIRCUS_WIPE, viewport, location)
  }
)

# The pan before the fight already plays War.
alias desert_pbMomDadBattleIntro pbMomDadBattleIntro
def pbMomDadBattleIntro(event)
  DesertScreens.set_circus_music
  desert_pbMomDadBattleIntro(event)
end

alias desert_pbMomDadBattleStart pbMomDadBattleStart
def pbMomDadBattleStart
  DesertScreens.set_circus_music
  setBattleRule("backdrop", DesertScreens::CIRCUS_BACKDROP)
  begin
    return desert_pbMomDadBattleStart
  ensure
    DesertScreens.clear_circus_music
  end
end

# The stock base lookup appends the environment ("circus_grass"); the circus bases have no variant.
if defined?(Battle::Scene)
  class Battle::Scene
    alias desert_pbCreateBackdropSprites pbCreateBackdropSprites unless method_defined?(:desert_pbCreateBackdropSprites)

    def pbCreateBackdropSprites
      @battle.backdropBase = nil if DesertScreens.circus_active?
      desert_pbCreateBackdropSprites
    end
  end
end
