#===============================================================================
# Planetarium - F9 debug entries under Desert Town... (playtests only).
# The show entries never touch the saved quest state.
#===============================================================================

module Planet
  def self.reset
    $PokemonGlobal.planet_quest = PlanetRules.new_state if $PokemonGlobal
  end

  def self.debug_stage
    names = PlanetRules::STAGES.map(&:to_s)
    pick = pbMessage("Stage?", names + ["cancel"], names.length + 1)
    return if pick >= names.length
    fin = pbConfirmMessage("finished on?")
    PlanetRules.debug_set!(state, PlanetRules::STAGES[pick], fin)
  end

  def self.debug_ram
    if has_ram?
      $bag.remove(PlanetRules::ITEM, $bag.quantity(PlanetRules::ITEM))
    else
      $bag.add(PlanetRules::ITEM, 1)
    end
  end

  # Play from 5 s before a passage (or the silent gap); the debug clock may start mid-file.
  def self.debug_from
    timing = Show.load_timing
    return pbMessage("No timing file.") unless timing
    marks = PlanetRules.passage_spans(timing[:lines]).map { |pid, st, _| [pid, st] }
    segs = PlanetRules.scene_segments(timing, timing[:duration])
    gap = segs.find { |s| s[2] == PlanetRules::COUNTDOWN_SCENE }
    marks << ["gap", gap[0]] if gap
    pick = pbMessage("Play from?", marks.map(&:first) + ["cancel"], marks.length + 1)
    return if pick >= marks.length
    Show.prepare(from: [marks[pick][1] - 5, 0].max)&.play
  end

  def self.debug_info
    timing, audio = Show.sources
    info = ["timing: #{timing ? (timing[:placeholder] ? 'placeholder' : timing[:source]) : 'missing'}",
            "duration: #{timing ? timing[:duration] : '-'} s, lines: #{timing ? timing[:lines].length : 0}",
            "audio: #{audio ? 'present' : 'missing'}"]
    spans = timing ? PlanetRules.passage_spans(timing[:lines]) : []
    spans.each { |pid, st, en| info << format("%s %.1f-%.1f", pid, st, en) }
    info.each { |l| echoln("[Planetarium] #{l}") }
    pbMessage(info.first(3).join("\n"))
    pbMessage(spans.map { |pid, st, _| format("%s %.0f", pid, st) }.join("  ")) if spans.any?
  end

  DEBUG_ENTRIES = [
    [:dt_planet_stage, "Planetarium: set stage", "Sets the quest stage and the finished flag.", proc { Planet.debug_stage }],
    [:dt_planet_ram, "Planetarium: give/take little ram", "Gives LITTLERAM, or takes every one.", proc { Planet.debug_ram }],
    [:dt_planet_show, "Planetarium: play show", "Plays the show from 0. No state change.", proc { Planet::Show.prepare&.play }],
    [:dt_planet_from, "Planetarium: play from passage", "Plays from 5 s before P01..P13 or the gap. No state change.",
     proc { Planet.debug_from }],
    [:dt_planet_info, "Planetarium: info", "Timing source, duration, lines, audio, passage spans.", proc { Planet.debug_info }],
    [:dt_planet_reset, "Planetarium: reset quest", "Writes a fresh quest state (the ram stays).", proc { Planet.reset }]
  ].freeze
end

Planet::DEBUG_ENTRIES.each do |id, name, desc, action|
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
