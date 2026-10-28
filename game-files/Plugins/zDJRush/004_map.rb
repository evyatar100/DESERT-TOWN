#===============================================================================
# DJ Rush Hour - the party (Map093): art car event 82 runs pbDJRushCar(get_self), the
# dancing aliens 83-85 run pbDJRushCrowd. Looks follow the stage (no switch).
#===============================================================================

module DJRush
  PARTY_MAP = DJRushRules::PARTY_MAP
  CAR_EVENT = "djrush_car"
  CROWD_EVENTS = %w[djrush_crowd_1 djrush_crowd_2 djrush_crowd_3].freeze
  ROW_DIR = [2, 4, 6, 8].freeze       # sheet row -> page direction
  TALK_ROW = 2
  JAM = [%w[DJRUSH_JAM_HONK], %w[DJRUSH_JAM_ALIEN], %w[DJRUSH_JAM_DJ dj]].freeze
  PLAYER_DJ = "dt_fc898478"

  # Row 1 stuck before :freed, row 0 DJing from :freed on.
  def self.car_row(st = state) = DJRushRules.freed?(st) ? 0 : 1

  # The RPG map before its events are built: the car stuck, or from :freed on She Se on the
  # stage, Ido on the floor, all dancing, and the crowd gone (007_stage_swap.rb).
  def self.dress_map(map)
    st = state
    if DJRushRules.freed?(st)
      stage_dress_rpg(map)
      map.events.delete_if { |_, ev| CROWD_EVENTS.include?(ev.name) }
      return true
    end
    map.events.each_value do |ev|
      next unless ev.name == CAR_EVENT
      ev.pages.each do |pg|
        pg.direction_fix = true
        pg.step_anime = true
        pg.graphic.direction = ROW_DIR[car_row(st)]
        pg.graphic.character_name = Art.map_graphic
      end
    end
    true
  end

  def self.live_events(names)
    return [] unless on_map?(PARTY_MAP)
    $game_map.events.values.select { |e| names.include?(e.name) }
  end

  def self.set_row(ev, row, graphic = Art.map_graphic)
    ev.character_name = graphic
    ev.instance_variable_set(:@direction_fix, true)
    ev.instance_variable_set(:@step_anime, true)
    ev.direction = ROW_DIR[row]
  end

  # The live map: right after the win, and for a map restored from a save.
  def self.dress_live
    st = state
    stage_dress_live(st)
    live_events(CROWD_EVENTS).each(&:erase) if DJRushRules.freed?(st)
    true
  end

  # Before :freed: row 2 (the DJ faces the player and nods) while he talks, then the stuck row.
  # From :freed She Se is a normal charset that already faces the player.
  def self.talking
    return yield if DJRushRules.freed?(state)
    begin
      live_events([CAR_EVENT]).each { |ev| set_row(ev, TALK_ROW) }
      yield
    ensure
      live_events([CAR_EVENT]).each { |ev| set_row(ev, car_row) }
    end
  end

  def self.mirror?
    cs = $PokemonGlobal.desert_player_charset if $PokemonGlobal && $PokemonGlobal.respond_to?(:desert_player_charset)
    cs ||= $game_player.character_name if $game_player
    cs == PLAYER_DJ
  end

  def self.car_talk
    st = state
    case DJRushRules.car_decide(st, $bag)
    when :intro, :prompt_again then jam(st)
    when :meet then meet(st)
    when :remind
      talking { say("DJRUSH_DJ_REMIND", :dj) }
      replay_offer(st)
    when :reissue then reissue(st)
    when :after
      talking { say("DJRUSH_DJ_AFTER", :dj) }
      replay_offer(st)
    end
  end

  def self.crowd_talk
    jam(state) unless DJRushRules.crowd_decide(state) == :gone
  end

  # The first time the full jam, later one line with the floor number; then the prompt.
  def self.jam(st)
    if st[:stage] == :none
      JAM.each { |key, who| who ? talking { say(key, who.to_sym) } : say(key) }
      DJRushRules.start!(st)
      DesertTalk.name_key = nil if defined?(DesertTalk)
      ok = pbConfirmMessage(_INTL("DJRUSH_JAM_PROMPT"))
    else
      DesertTalk.name_key = nil if defined?(DesertTalk)
      ok = pbConfirmMessage(_INTL("DJRUSH_JAM_PROMPT_AGAIN", st[:cleared] + 1))
    end
    return say("DJRUSH_JAM_LATER") unless ok
    play_main(st)
  end

  def self.play_main(st)
    result = nil
    pbFadeOutIn do
      result = Scene.new(st, DJRushRules.levels_left(st)).run
      dress_live if result[:result] == :freed
    end
    say("DJRUSH_DJ_TO_STAGE", :dj) if result && result[:result] == :freed
    result
  end

  # HELLO, the mirror line if the player is DJ She Se, BAG_1/2, the item, the phrase.
  def self.meet(st)
    return false unless DJRushRules.give_bag!(st, $bag)
    talking do
      say("DJRUSH_DJ_HELLO", :dj)
      say("DJRUSH_DJ_MIRROR", :dj) if mirror?
      lines(%w[DJRUSH_DJ_BAG_1 DJRUSH_DJ_BAG_2], :dj)
    end
    announce
    talking { say("DJRUSH_DJ_PHRASE", :dj) }
    true
  end

  # DJ_REISSUE already carries the phrase.
  def self.reissue(st)
    return false unless DJRushRules.reissue!(st, $bag)
    talking { say("DJRUSH_DJ_REISSUE", :dj) }
    announce
    true
  end

  # After the meeting: replay one board, best only.
  def self.replay_offer(st)
    DesertTalk.name_key = NAME_KEYS[:dj] if defined?(DesertTalk)
    return nil unless pbConfirmMessage(_INTL("DJRUSH_REPLAY_PROMPT"))
    rows = DJRushRules::LEVELS.each_index.map { |i| level_label(i) }
    pick = pbMessage(_INTL("DJRUSH_REPLAY_PICK"), rows, -1)
    return nil unless pick.is_a?(Integer) && pick.between?(0, rows.length - 1)
    result = nil
    pbFadeOutIn { result = Scene.new(st, [pick], replay: true).run }
    result
  end
end

def pbDJRushCar(_event = nil)
  DJRush.car_talk if DJRush.on_map?(DJRush::PARTY_MAP)
  true
end

def pbDJRushCrowd
  DJRush.crowd_talk if DJRush.on_map?(DJRush::PARTY_MAP)
  true
end

EventHandlers.add(:on_game_map_setup, :djrush_party,
  proc { |map_id, map, _tileset|
    next if map_id != DJRush::PARTY_MAP
    DJRush.dress_map(map)
  }
)

EventHandlers.add(:on_map_or_spriteset_change, :djrush_saved_map,
  proc { |_scene, _map_changed| DJRush.dress_live }
)
