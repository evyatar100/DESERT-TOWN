#===============================================================================
# DJ Rush Hour - F9 debug entries (Debug > Desert Town...): play a board, warp to the
# art car or to Johnny, set the stage, drop the Music Bag, reset.
#===============================================================================

module DJRush
  CAR_WARP = [PARTY_MAP, 12, 25, 8].freeze               # below the car, facing up
  STAGE_WARP = [PARTY_MAP, 33, 14, 8].freeze            # below the booth, facing up
  JOHNNY_WARP = [DJRushRules::PLAYA_MAP, 36, 25, 8].freeze # below Johnny, facing up

  def self.debug_warp(spot)
    $game_temp.player_new_map_id    = spot[0]
    $game_temp.player_new_x         = spot[1]
    $game_temp.player_new_y         = spot[2]
    $game_temp.player_new_direction = spot[3]
    $scene.transfer_player
    $game_map.refresh
  end

  def self.close_debug_menu(sprites, viewport)
    pbFadeOutAndHide(sprites)
    pbDisposeMessageWindow(sprites["textbox"])
    pbDisposeSpriteHash(sprites)
    viewport.dispose
  end

  def self.debug_on_map?
    return true if $PokemonGlobal && $scene.is_a?(Scene_Map)
    pbMessage("Load a game on the map first.")
    false
  end

  def self.debug_set(stage)
    DJRushRules.debug_set!(state, $bag, stage)
    dress_live
  end

  def self.debug_reset
    return unless $PokemonGlobal
    $PokemonGlobal.dj_rush = DJRushRules.new_state
    $bag.remove(DJRushRules::ITEM, $bag.quantity(DJRushRules::ITEM)) if $bag && $bag.quantity(DJRushRules::ITEM) > 0
  end
end

MenuHandlers.add(:debug_menu, :dt_djrush_play, {
  "name"        => "DJ Rush: play a board (1/2/3)",
  "parent"      => :desert_town_menu,
  "description" => "Plays one DJ Rush Hour board. Nothing is recorded.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    next false unless DJRush.debug_on_map?
    names = ["Board 1", "Board 2", "Board 3", "Cancel"]
    pick = pbShowCommands(nil, names, names.length)
    next false unless pick.between?(0, 2)
    DJRush.close_debug_menu(sprites, viewport)
    pbFadeOutIn { DJRush::Scene.new(DJRush.state, [pick], replay: true, record: false).run }
    next true
  }
})

MenuHandlers.add(:debug_menu, :dt_djrush_warp_car, {
  "name"        => "DJ Rush: warp to the art car",
  "parent"      => :desert_town_menu,
  "description" => "Warps to Map093 (12,25), facing up at the crowd and the art car.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    next false unless DJRush.debug_on_map?
    DJRush.close_debug_menu(sprites, viewport)
    DJRush.debug_warp(DJRush::CAR_WARP)
    next true
  }
})

MenuHandlers.add(:debug_menu, :dt_djrush_warp_stage, {
  "name"        => "DJ Rush: warp to the booth",
  "parent"      => :desert_town_menu,
  "description" => "Warps to Map093 (33,14), facing up at the stage booth.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    next false unless DJRush.debug_on_map?
    DJRush.close_debug_menu(sprites, viewport)
    DJRush.debug_warp(DJRush::STAGE_WARP)
    next true
  }
})

MenuHandlers.add(:debug_menu, :dt_djrush_warp_johnny, {
  "name"        => "DJ Rush: warp to Johnny",
  "parent"      => :desert_town_menu,
  "description" => "Warps to Map098 (36,25), facing up at Johnny on the Playa.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    next false unless DJRush.debug_on_map?
    DJRush.close_debug_menu(sprites, viewport)
    DJRush.debug_warp(DJRush::JOHNNY_WARP)
    next true
  }
})

MenuHandlers.add(:debug_menu, :dt_djrush_stage, {
  "name"        => "DJ Rush: set the stage",
  "parent"      => :desert_town_menu,
  "description" => "none/intro/freed/bag/done. One Music Bag is held in 'bag' and 'done', none before.",
  "always_show" => true,
  "effect"      => proc {
    next false unless DJRush.debug_on_map?
    names = DJRushRules::STAGES.map(&:to_s) + ["Cancel"]
    pick = pbShowCommands(nil, names, names.length)
    next false unless pick.between?(0, DJRushRules::STAGES.length - 1)
    DJRush.debug_set(DJRushRules::STAGES[pick])
    pbMessage("DJ Rush stage: #{names[pick]}.")
    next false
  }
})

MenuHandlers.add(:debug_menu, :dt_djrush_drop_bag, {
  "name"        => "DJ Rush: drop the Music Bag",
  "parent"      => :desert_town_menu,
  "description" => "Removes every Music Bag (tests the DJ's reissue).",
  "always_show" => true,
  "effect"      => proc {
    next false unless DJRush.debug_on_map?
    n = $bag.quantity(DJRushRules::ITEM)
    $bag.remove(DJRushRules::ITEM, n) if n > 0
    pbMessage("Music Bags removed: #{n}.")
    next false
  }
})

MenuHandlers.add(:debug_menu, :dt_djrush_reset, {
  "name"        => "DJ Rush: reset",
  "parent"      => :desert_town_menu,
  "description" => "Stage none, no boards cleared, no bests, no Music Bag.",
  "always_show" => true,
  "effect"      => proc {
    next false unless DJRush.debug_on_map?
    DJRush.debug_reset
    pbMessage("DJ Rush reset. Re-enter the party map to see the crowd again.")
    next false
  }
})
