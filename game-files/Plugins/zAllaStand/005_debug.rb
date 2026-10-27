#===============================================================================
# AllaStand - F9 debug entries under Desert Town... and AllaStand.reset (playtests only).
#===============================================================================

module AllaStand
  WARP = [11, 15, 8].freeze   # the tile below Alla (Map098 ev15 at 11,14), facing up at him

  # Fresh quest and session state; an ALLAHOTDOG already in the bag stays.
  def self.reset
    $PokemonGlobal.alla_stand = AllaRules.new_state if $PokemonGlobal
    reset_easing
    @pre_seen = @after_turn = @camper_after = nil
  end

  def self.debug_jump
    names = ["campaign", "campaign + 3 votes", "rush", "done", "Cancel"]
    stage = AllaRules::JUMP_STAGES[pbMessage("Jump to stage:", names, names.length)]
    return false unless stage
    AllaRules.debug_jump!(state, stage, $bag)
  end

  # The rush at the current easing; quest state and easing stay untouched.
  def self.debug_rush
    r = run_rush(record: false)
    pbMessage("Hot-dog rush: passed=#{r[:passed]} correct=#{r[:correct]} shown=#{r[:shown]}")
  end

  def self.debug_warp
    $game_temp.player_new_map_id    = PLAYA_MAP
    $game_temp.player_new_x         = WARP[0]
    $game_temp.player_new_y         = WARP[1]
    $game_temp.player_new_direction = WARP[2]
    $scene.transfer_player
    $game_map.refresh
  end

  # Closes the debug menu the way the stock warp does.
  def self.close_debug_menu(sprites, viewport)
    pbFadeOutAndHide(sprites)
    pbDisposeMessageWindow(sprites["textbox"])
    pbDisposeSpriteHash(sprites)
    viewport.dispose
  end

  DEBUG_ENTRIES = [
    [:dt_alla_reset, "Alla: reset quest", "New quest state and easing; an ALLAHOTDOG already in the bag stays.",
     proc { AllaStand.reset }],
    [:dt_alla_jump, "Alla: jump to stage...", "campaign / campaign + 3 votes / rush / done.",
     proc { AllaStand.debug_jump }],
    [:dt_alla_rush, "Alla: test hot-dog rush (no state change)", "Runs the Hot-Dog Rush at the current easing and shows the result.",
     proc { AllaStand.debug_rush }]
  ].freeze
end

AllaStand::DEBUG_ENTRIES.each do |id, name, desc, action|
  MenuHandlers.add(:debug_menu, id, {
    "name"        => name,
    "parent"      => :desert_town_menu,
    "description" => desc,
    "always_show" => true,
    "effect"      => proc {
      if !$player || !$bag
        pbMessage("No player loaded yet.")
        next false
      end
      action.call
      pbMessage("Done.")
      next false
    }
  })
end

MenuHandlers.add(:debug_menu, :dt_alla_warp, {
  "name"        => "Alla: warp to stand",
  "parent"      => :desert_town_menu,
  "description" => "Warps to Map098 (11,15), facing Alla at the giant hot dog.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    AllaStand.close_debug_menu(sprites, viewport)
    AllaStand.debug_warp
    next true
  }
})
