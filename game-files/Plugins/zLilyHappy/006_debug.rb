#===============================================================================
# LilyHappy - F9 entries (Debug > Desert Town...): play without recording, warp below Lily
# on the Playa, set the stage, reset.
#===============================================================================

module LilyHappy
  WARP = [SPOT[0], SPOT[1] + 1, 8].freeze   # below Lily, facing up
  DEBUG_STAGES = { "none" => :none, "asked + 4 heard" => :asked, "wheeled" => :wheeled, "done" => :done }.freeze

  def self.debug_warp
    $game_temp.player_new_map_id    = MAP_ID
    $game_temp.player_new_x         = WARP[0]
    $game_temp.player_new_y         = WARP[1]
    $game_temp.player_new_direction = WARP[2]
    $scene.transfer_player
    $game_map.refresh
  end

  # Replaces the saved hash's content in place, so held references stay live.
  def self.debug_set(stage)
    return unless $PokemonGlobal
    st = $PokemonGlobal.lily_happy
    st.replace(LilyHappyRules.state_at(stage))
  end

  def self.close_debug_menu(sprites, viewport)
    pbFadeOutAndHide(sprites)
    pbDisposeMessageWindow(sprites["textbox"])
    pbDisposeSpriteHash(sprites)
    viewport.dispose
  end

  def self.on_map?
    return true if $PokemonGlobal && $scene.is_a?(Scene_Map)
    pbMessage("Load a game on the map first.")
    false
  end
end

MenuHandlers.add(:debug_menu, :dt_lily_happy_play, {
  "name"        => "LilyHappy: play the wheel (not recorded)",
  "parent"      => :desert_town_menu,
  "description" => "Runs the Wheel of Happiness. Nothing is saved.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    next false unless LilyHappy.on_map?
    LilyHappy.close_debug_menu(sprites, viewport)
    LilyHappy.play(LilyHappy.state, record: false)
    next true
  }
})

MenuHandlers.add(:debug_menu, :dt_lily_happy_warp, {
  "name"        => "LilyHappy: warp to Lily",
  "parent"      => :desert_town_menu,
  "description" => "Warps to Map098 below Lily (5,3), facing up.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    next false unless LilyHappy.on_map?
    LilyHappy.close_debug_menu(sprites, viewport)
    LilyHappy.debug_warp
    next true
  }
})

MenuHandlers.add(:debug_menu, :dt_lily_happy_stage, {
  "name"        => "LilyHappy: set the stage",
  "parent"      => :desert_town_menu,
  "description" => "none / asked with 4 complaints heard / wheeled / done.",
  "always_show" => true,
  "effect"      => proc {
    next false unless LilyHappy.on_map?
    names = LilyHappy::DEBUG_STAGES.keys
    pick = pbShowCommands(nil, names + ["Cancel"], names.length + 1)
    next false unless pick.is_a?(Integer) && pick.between?(0, names.length - 1)
    LilyHappy.debug_set(LilyHappy::DEBUG_STAGES[names[pick]])
    pbMessage("Stage: #{names[pick]}")
    next false
  }
})

MenuHandlers.add(:debug_menu, :dt_lily_happy_reset, {
  "name"        => "LilyHappy: reset the quest",
  "parent"      => :desert_town_menu,
  "description" => "Back to a fresh quest (stage none, nothing heard).",
  "always_show" => true,
  "effect"      => proc {
    next false unless LilyHappy.on_map?
    LilyHappy.debug_set(:none)
    pbMessage("LilyHappy quest reset.")
    next false
  }
})
