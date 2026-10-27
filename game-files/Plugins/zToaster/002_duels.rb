#===============================================================================
# Toaster - the one duel (Eyal HaNoodles on 95, a loyalty test) through pbDuel.
# Speeches are in pbDuel's order: 3 defend, 3 precise, 3 fierce, 3 special.
#===============================================================================

module Toaster
  DUELS = {
    noodles: {
      map: KUSOMO_MAP, event: "dt_c081cd67", name: "NAME_C081CD67",
      moves: %w[TOAST_NOODLE_MOVE1 TOAST_NOODLE_MOVE2 TOAST_NOODLE_MOVE3 TOAST_NOODLE_MOVE4],
      speeches: %w[TOAST_NOODLE_BLK1 TOAST_NOODLE_BLK2 TOAST_NOODLE_BLK3
                   TOAST_NOODLE_PRC1 TOAST_NOODLE_PRC2 TOAST_NOODLE_PRC3
                   TOAST_NOODLE_FRC1 TOAST_NOODLE_FRC2 TOAST_NOODLE_FRC3
                   TOAST_NOODLE_SPC1 TOAST_NOODLE_SPC2 TOAST_NOODLE_SPC3]
    }
  }.freeze
  DUEL_TRAINER = :BLACKBELT

  # The talking event: the running interpreter's own event, else the map event by name.
  def self.duel_event(name)
    interp = pbMapInterpreter if defined?(pbMapInterpreter)
    ev = interp.get_self if interp && interp.respond_to?(:get_self)
    return ev if ev && ev.respond_to?(:name) && ev.name == name
    $game_map.events.values.find { |e| e.name == name }
  end

  # True on a win. A loss changes nothing.
  def self.duel(which)
    d = DUELS[which]
    DesertTalk.name_key = d[:name] if defined?(DesertTalk)
    speeches = d[:speeches].map { |k| _INTL(k) }
    pbDuel(DUEL_TRAINER, _INTL(d[:name]), duel_event(d[:event]), speeches) == true
  end
end

# DesertTalk/duel_moves.rb owns the Hash; zToaster only adds its one key.
Toaster::DUELS.each_value do |d|
  DESERT_DUEL_PROFILES[[d[:map], d[:event]]] = { :moves => d[:moves], :name => d[:name] }
end
