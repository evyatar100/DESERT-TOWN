#===============================================================================
# Toaster - F9 debug entries under Desert Town... and Toaster.reset (playtests only).
#===============================================================================

module Toaster
  # Fresh quest, the 3 quest items gone; the altar redresses on the next map load.
  def self.reset
    $PokemonGlobal.toaster_quest = ToasterRules.new_state if $PokemonGlobal
    return unless $bag
    ToasterRules::ITEMS.each { |i| $bag.remove(i, $bag.quantity(i)) if $bag.quantity(i) > 0 }
  end

  def self.debug_jump
    names = ToasterRules::JUMP_STAGES.map(&:to_s) + ["Cancel"]
    pick = pbMessage("Jump to stage (holds that stage's item):", names, names.length)
    stage = ToasterRules::JUMP_STAGES[pick]
    return false unless stage
    ToasterRules.debug_jump!(state, $bag, stage)
  end

  # Runs the lent-party Rotom fight only; the quest state is never read or written.
  def self.debug_battle
    outcome = final_battle
    pbMessage("Battle outcome: #{outcome} (#{ToasterRules.battle_won?(outcome) ? 'win' : 'not a win'}).")
  end

  DEBUG_ENTRIES = [
    [:dt_toaster_reset, "Toaster: reset quest", "New quest state and the 3 toaster items removed.",
     proc { Toaster.reset }],
    [:dt_toaster_jump, "Toaster: jump to stage...", "asked / lead / permit / toaster, holding exactly that stage's item.",
     proc { Toaster.debug_jump }],
    [:dt_toaster_battle, "Toaster: test final battle (no state change)", "Runs the lent-party Heat Rotom battle and shows the outcome code.",
     proc { Toaster.debug_battle }]
  ].freeze
end

Toaster::DEBUG_ENTRIES.each do |id, name, desc, action|
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
