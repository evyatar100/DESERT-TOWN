#===============================================================================
# Toaster - hooks after HaNoodles/Oren (map 95) and Yunik's injected call (map 80).
#===============================================================================

module Toaster
  ASK = %w[TOAST_NOODLE_ASK_1 TOAST_NOODLE_ASK_2 TOAST_NOODLE_ASK_3 TOAST_NOODLE_ASK_4].freeze
  GIVER_REMIND = {
    remind_clerk: "TOAST_NOODLE_REMIND_CLERK", remind_vault: "TOAST_NOODLE_REMIND_VAULT",
    remind_altar: "TOAST_NOODLE_REMIND_ALTAR"
  }.freeze
  GIVER_AFTER = %w[TOAST_NOODLE_AFTER_1 TOAST_NOODLE_AFTER_2 TOAST_NOODLE_AFTER_3].freeze
  NOODLE_PRE = %w[TOAST_NOODLE_PRE_1 TOAST_NOODLE_PRE_2 TOAST_NOODLE_PRE_3].freeze
  CLERK_PRE = %w[TOAST_CLERK_PRE_1 TOAST_CLERK_PRE_2 TOAST_CLERK_PRE_3].freeze
  RETRY_CHOICES = %w[TOAST_RETRY_YES TOAST_RETRY_NO].freeze
  CLERK_SCRIPT = "pbToasterClerk"
  CLERK_EVENT = "dt_326f5ab5"

  def self.after_talk(character_id)
    return unless on_map?(KUSOMO_MAP)
    case character_id
    when NOODLES then giver_talk
    when OREN then say("TOAST_OREN_AC_AFTER", :oren) if ToasterRules.oren_after?(state)
    end
  end

  def self.giver_talk
    st = state
    case (d = ToasterRules.giver_decide(st, $bag))
    when :intro
      ToasterRules.ask!(st)
      lines(ASK, :noodles)
      noodle_duel(st)
    when :duel then noodle_duel(st)
    when :finale then finale(st)
    when :crumb_recover then crumb_recover(st)
    when :after
      @after_turn = ((@after_turn || -1) + 1) % GIVER_AFTER.length
      say(GIVER_AFTER[@after_turn], :noodles)
    else say(GIVER_REMIND[d], :noodles)
    end
  end

  # The full intro once a session, then only its last line before a retry.
  def self.pre_duel(which, keys, speaker)
    @pre_seen ||= {}
    lines(@pre_seen[which] ? keys.last(1) : keys, speaker)
    @pre_seen[which] = true
  end

  def self.noodle_duel(st)
    pre_duel(:noodles, NOODLE_PRE, :noodles)
    return say("TOAST_NOODLE_LOSE", :noodles) unless duel(:noodles)
    ToasterRules.lead!(st)
    lines(%w[TOAST_NOODLE_WIN_1 TOAST_NOODLE_WIN_2], :noodles)
  end

  # Yunik asks "again?"; No or Back is false.
  def self.retry?(ask_key)
    choose(ask_key, :clerk, RETRY_CHOICES) == 0
  end

  def self.clerk_talk
    st = state
    case ToasterRules.clerk_decide(st, $bag)
    when :hearing then hearing(st)
    when :reissue
      return unless ToasterRules.reissue!(st, $bag)
      say("TOAST_CLERK_REISSUE", :clerk)
      announce(ToasterRules::PERMIT)
      say("TOAST_CLERK_REMIND", :clerk)
    when :remind then say("TOAST_CLERK_REMIND", :clerk)
    when :closed then say("TOAST_CLERK_CLOSED", :clerk)
    end
  end

  # The Stamp Desk, again at once on "yes"; only a pass changes the quest.
  def self.hearing(st)
    pre_duel(:clerk, CLERK_PRE, :clerk)
    loop do
      if run_desk[:passed]
        return unless ToasterRules.permit!(st, $bag)
        say("TOAST_CLERK_WIN_1", :clerk)
        announce(ToasterRules::PERMIT)
        return lines(%w[TOAST_CLERK_WIN_2 TOAST_CLERK_WIN_3 TOAST_CLERK_WIN_4], :clerk)
      end
      say("TOAST_CLERK_LOSE", :clerk)
      return unless retry?("TOAST_RETRY_HEARING_ASK")
    end
  end

  # One hearing at the current easing; record: false for the F9 test run.
  def self.run_desk(record: true)
    DesertTalk.name_key = nil if defined?(DesertTalk)
    result = DeskScene.new(desk_losses, rand(1 << 30)).run
    record_desk(result[:passed]) if record
    result
  end

  # Appends `pbToasterClerk` to Yunik's talk (Action) page(s), once; other pages untouched.
  def self.inject_clerk(map)
    ev = map.events.values.find { |e| e.name == CLERK_EVENT }
    return false unless ev
    ev.pages.each do |page|
      next unless clerk_page?(page)
      inject_list(page.list)
    end
    true
  end

  def self.clerk_page?(page)
    cmds = page.list.map { |c| [c.code, c.parameters] }
    ToasterRules.talk_page?(page.trigger, cmds, "pbDesertSpeaker(\"#{CLERK}\")", "MSG_#{CLERK.upcase}")
  end

  def self.inject_list(list)
    return false if list.any? { |c| c.code == 355 && c.parameters[0] == CLERK_SCRIPT }
    at = ToasterRules.inject_index(list.map(&:code))
    return false unless at
    list.insert(at, RPG::EventCommand.new(355, 0, [CLERK_SCRIPT]))
    true
  end

  # A map restored from a save skips :on_game_map_setup: redo both edits, idempotently.
  def self.restore_saved_map
    return unless $game_map
    rpg = $game_map.instance_variable_get(:@map)
    return unless rpg
    case $game_map.map_id
    when CLERK_MAP
      inject_clerk(rpg)
      live = $game_map.events.values.find { |e| e.name == CLERK_EVENT }
      list = live && live.instance_variable_get(:@list)
      inject_list(list) if list && live.instance_variable_get(:@page) && clerk_page?(live.instance_variable_get(:@page))
    when ALTAR_MAP
      dress_altar(rpg)
      live = $game_map.events.values.find { |e| e.name == ALTAR_EVENT }
      live.character_name = altar_look if live
    end
  end
end

alias toaster_pbDesertTalk pbDesertTalk unless defined?(toaster_pbDesertTalk)
def pbDesertTalk(character_id, line_key = nil)
  ret = toaster_pbDesertTalk(character_id, line_key)
  Toaster.after_talk(character_id)
  ret
end

# Yunik at the Old City only; anywhere else the call does nothing.
def pbToasterClerk
  Toaster.clerk_talk if Toaster.on_map?(Toaster::CLERK_MAP)
  true
end

EventHandlers.add(:on_game_map_setup, :toaster_clerk,
  proc { |map_id, map, _tileset|
    next if map_id != Toaster::CLERK_MAP
    Toaster.inject_clerk(map)
  }
)

EventHandlers.add(:on_map_or_spriteset_change, :toaster_saved_map,
  proc { |_scene, _map_changed| Toaster.restore_saved_map }
)
