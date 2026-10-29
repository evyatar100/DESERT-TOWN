#===============================================================================
# QuestMarks - F9 entries (Debug > Desert Town...): list this map's marks per client, and
# toggle quest-giver marks for this session only.
#===============================================================================

module QuestMarks
  def self.debug_lines(map_id)
    index = names_index($game_map.events)
    lines = results(map_id).map do |key, res|
      ids = QuestMarksRules.resolve([res], index, givers: givers?)
      "#{key}: next #{Array(res[:next]).inspect}, giver #{Array(res[:giver]).inspect} -> #{ids.inspect}"
    end
    lines += clients.select { |k| disabled?(k) }.map { |k| "#{k}: DISABLED (raised)" }
    lines.empty? ? ["No quest marks clients registered."] : lines
  end
end

MenuHandlers.add(:debug_menu, :dt_quest_marks_list, {
  "name"        => "Quest marks: list this map",
  "parent"      => :desert_town_menu,
  "description" => "Shows each quest's '!' targets on this map and the event ids they resolve to.",
  "always_show" => true,
  "effect"      => proc {
    next false unless $game_map && $scene.is_a?(Scene_Map)
    pbMessage("Map #{$game_map.map_id}, givers #{QuestMarks.givers? ? 'on' : 'off'}.")
    QuestMarks.debug_lines($game_map.map_id).each { |l| pbMessage(l) }
    next false
  }
})

MenuHandlers.add(:debug_menu, :dt_quest_marks_givers, {
  "name"        => "Quest marks: toggle givers (session)",
  "parent"      => :desert_town_menu,
  "description" => "Shows or hides the '!' over quest givers until the game is closed. Not saved.",
  "always_show" => true,
  "effect"      => proc {
    QuestMarks.givers = !QuestMarks.givers?
    QuestMarks::Overlay.dirty!
    pbMessage("Quest-giver marks: #{QuestMarks.givers? ? 'on' : 'off'} (this session).")
    next false
  }
})
