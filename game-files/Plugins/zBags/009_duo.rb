#===============================================================================
# Bags - Esther and Shirpaz as engine followers during the song, and their exit:
# the founder's end line, a short walk (north on Map095, toward the Spaceship),
# a fade, and they are gone. Same follower and scene plumbing as zFlamingoBand.
# Also Bags.say/choose: a duo line turns them to the player first.
#===============================================================================

module Bags
  module Duo
    FOLLOWER_PREFIX = "bags_duo_"
    LEAVE_STEPS = 4
    FADE_FRAMES = 10
    END_LINE = "BAGS_UNICORN_SONG_END"

    def self.follower_name(which)
      "#{FOLLOWER_PREFIX}#{which}"
    end

    # FlamingoBand's check: no message, menu, battle, transfer, event or forced move.
    def self.scene_safe?
      return false if !$scene.is_a?(Scene_Map) || !$game_map || !$game_player || !$game_temp
      return false if $game_temp.message_window_showing || $game_temp.in_battle
      return false if $game_temp.player_transferring || $game_temp.in_menu
      return false if pbMapInterpreterRunning?
      return false if $game_player.move_route_forcing
      true
    end

    # Runs a script through the map interpreter, so the player is locked while it plays.
    def self.run_scene(script)
      list = [RPG::EventCommand.new(355, 0, [script]), RPG::EventCommand.new(0, 0, [])]
      pbMapInterpreter.setup(list, 0)
    end

    # [[which, Game_Follower, FollowerData], ...] for the duo followers that exist.
    def self.followers
      out = []
      return out if !$game_temp || !$game_temp.followers || !$PokemonGlobal
      $game_temp.followers.each_follower do |event, data|
        UNICORNS.each { |w| out << [w, event, data] if event && data.name == follower_name(w) }
      end
      out
    end

    # Esther first (right behind the player), then Shirpaz, from their tiles and charsets.
    # The map events hide through S106 once the duo is touring.
    def self.join
      return false unless BagsRules.tour!(Bags.state)
      UNICORNS.each do |which|
        ev = Bags.unicorn_event(which)
        next unless ev && !ev.character_name.to_s.empty?
        name = follower_name(which)
        next if $PokemonGlobal.followers.any? { |data| data.name == name }
        $game_temp.followers.add_follower(ev, name)
      end
      Bags.sync_switch
      true
    end

    def self.remove_followers
      return if !$game_temp || !$PokemonGlobal
      UNICORNS.each { |w| $game_temp.followers.remove_follower_by_name(follower_name(w)) }
    end

    # Turns the duo toward the player: the followers while touring, else the map events.
    def self.face_player
      return unless $game_player && $game_map
      chars = followers.map { |_, event, _| event }
      chars = UNICORNS.filter_map { |w| Bags.unicorn_event(w) } if chars.empty?
      chars.each { |ch| pbTurnTowardEvent(ch, $game_player) unless ch.character_name.to_s.empty? }
    end

    # The end scene (map interpreter): line, walk off, fade, then gone. Always ends :gone.
    def self.leave_scene
      duo = followers
      duo.each { |_, _, data| data.invisible_after_transfer = false }
      Bags.say(END_LINE, :esther)
      DesertTalk.name_key = nil if defined?(DesertTalk)
      dir = BagsRules.leave_dir($game_map.map_id)
      Bags.walk_together(duo.map { |_, event, _| [event, Array.new(LEAVE_STEPS, dir)] })
      FADE_FRAMES.times do
        duo.each { |_, event, _| event.opacity = [event.opacity - 26, 0].max }
        Bags.update_frame
      end
    ensure
      gone!
    end

    # Followers removed, :gone, S106 off. Also the cleanup for a save loaded mid-song.
    def self.gone!
      remove_followers
      BagsRules.leave!(Bags.state) if $PokemonGlobal
      Bags.sync_switch
    end

    # A save made mid-song loads as "song over, gone to the Spaceship"; no item changes.
    def self.after_load
      return unless $PokemonGlobal && Bags.state[:duo] == :touring
      gone!
    end
  end

  DUO_SPEAKERS = %i[esther shirpaz duo].freeze

  # Shows one line with the speaker's name plate (:none clears it). The duo faces the player first.
  def self.say(key, speaker = :none, *args)
    Duo.face_player if DUO_SPEAKERS.include?(speaker)
    DesertTalk.name_key = NAME_KEYS[speaker] if defined?(DesertTalk)
    pbMessage(_INTL(key, *args))
  end

  # pbMessage with choices; Back picks the last option.
  def self.choose(key, speaker, choice_keys)
    Duo.face_player if DUO_SPEAKERS.include?(speaker)
    DesertTalk.name_key = NAME_KEYS[speaker] if defined?(DesertTalk)
    pbMessage(_INTL(key), choice_keys.map { |k| _INTL(k) }, choice_keys.length)
  end
end
