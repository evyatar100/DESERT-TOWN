#===============================================================================
# Toaster - F9 debug entries under Desert Town... and Toaster.reset (playtests only).
#===============================================================================

module Toaster
  # Fresh quest, easing and session intros cleared, the 3 quest items gone; the altar redresses on the next map load.
  def self.reset
    $PokemonGlobal.toaster_quest = ToasterRules.new_state if $PokemonGlobal
    reset_easing
    @pre_seen = @vault_seen = @after_turn = nil
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

  # The two mini-games at the current easing; quest state and easing stay untouched.
  def self.debug_desk
    r = run_desk(record: false)
    pbMessage("Stamp desk: passed=#{r[:passed]} correct=#{r[:correct]} shown=#{r[:shown]}")
  end

  def self.debug_eviction
    r = run_eviction(record: false)
    pbMessage("Eviction: won=#{r[:won]} hits=#{r[:hits]}")
  end

  DEBUG_ENTRIES = [
    [:dt_toaster_reset, "Toaster: reset quest", "New quest state and the 3 toaster items removed.",
     proc { Toaster.reset }],
    [:dt_toaster_jump, "Toaster: jump to stage...", "asked / lead / permit / toaster, holding exactly that stage's item.",
     proc { Toaster.debug_jump }],
    [:dt_toaster_desk, "Toaster: test stamp desk (no state change)", "Runs Yunik's Stamp Desk at the current easing and shows the result.",
     proc { Toaster.debug_desk }],
    [:dt_toaster_evict, "Toaster: test eviction (no state change)", "Runs the vault Eviction at the current easing and shows the result.",
     proc { Toaster.debug_eviction }]
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
