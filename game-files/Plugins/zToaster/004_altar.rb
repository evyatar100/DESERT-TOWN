#===============================================================================
# Toaster - the casino altar (Map094 ev9 runs pbToasterAltar), the lent-party
# Heat Rotom battle and the way out to the Old City.
#===============================================================================

module Toaster
  ALTAR_EVENT = "toaster_altar"

  def self.altar_art?
    !!pbResolveBitmap("Graphics/Characters/#{ToasterRules::ALTAR_ART}")
  end

  # The one writer of the altar look, from the quest state.
  def self.altar_look
    ToasterRules.altar_graphic(ToasterRules.altar_decide(state, $bag), altar_art?)
  end

  # Sets the altar page graphic from the quest state before the events are built.
  def self.dress_altar(map)
    ev = map.events.values.find { |e| e.name == ALTAR_EVENT }
    return false unless ev
    look = altar_look
    ev.pages.each { |page| page.graphic.character_name = look }
    true
  end

  def self.altar_talk
    st = state
    case ToasterRules.altar_decide(st, $bag)
    when :sealed then say("TOAST_ALTAR_SEALED")
    when :fight then altar_fight(st)
    when :regive
      return unless ToasterRules.regive!(st, $bag)
      say("TOAST_ALTAR_REGIVE")
      announce(ToasterRules::TOASTER)
    else say("TOAST_ALTAR_EMPTY")
    end
  end

  def self.altar_fight(st)
    pbSEPlay("Voltorb Flip explosion")
    $game_screen.start_shake(5, 5, 20) if $game_screen
    rotom = toaster_rotom
    rotom.play_cry
    lines(%w[TOAST_ALTAR_POSSESSED_1 TOAST_ALTAR_POSSESSED_2])
    outcome = final_battle(rotom)
    if ToasterRules.battle_won?(outcome) && ToasterRules.claim!(st, $bag)
      live = $game_map.events.values.find { |e| e.name == ALTAR_EVENT }
      live.character_name = altar_look if live
      pbSEPlay("Slots coin")
      lines(%w[TOAST_ALTAR_WIN_1 TOAST_ALTAR_WIN_2])
      announce(ToasterRules::TOASTER)
      say("TOAST_GOT_TOASTER")
    else
      say("TOAST_ALTAR_LOSE")
    end
    escort_out
  end

  # "The toaster": Lv70 Heat Rotom with its oven moves, IVs 31, full HP.
  def self.toaster_rotom
    pkmn = Pokemon.new(:ROTOM, ToasterRules::ROTOM_LEVEL)
    pkmn.form_simple = ToasterRules::ROTOM_FORM
    pkmn.name = _INTL("TOAST_ROTOM_NAME")
    pkmn.forget_all_moves
    ToasterRules::ROTOM_MOVES.each { |m| pkmn.learn_move(m) }
    GameData::Stat.each_main { |s| pkmn.iv[s.id] = 31 }
    pkmn.calc_stats
    pkmn.heal
    pkmn
  end

  # The circus party on loan for this one fight; the player's own party always comes back.
  # Returns the raw outcome (1 win; 2 loss, 3 run, 5 draw).
  def self.final_battle(rotom = toaster_rotom)
    old_party = $player.party
    $player.party = pbShadowBasicParty
    begin
      ToasterRules::BATTLE_RULES.each { |rule| setBattleRule(rule) }
      return WildBattle.start_core(rotom)
    ensure
      $player.party = old_party
    end
  end

  # Win or loss: out to the Old City, the same tile a mummy touch lands on.
  def self.escort_out
    DesertTalk.name_key = nil if defined?(DesertTalk)
    pbFadeOutIn do
      pbTransferPlayer(ToasterRules::OUT_MAP, ToasterRules::OUT_X, ToasterRules::OUT_Y, ToasterRules::OUT_DIR)
    end
  end
end

def pbToasterAltar
  Toaster.altar_talk if Toaster.on_map?(Toaster::ALTAR_MAP)
  true
end

EventHandlers.add(:on_game_map_setup, :toaster_altar,
  proc { |map_id, map, _tileset|
    next if map_id != Toaster::ALTAR_MAP
    Toaster.dress_altar(map)
  }
)
