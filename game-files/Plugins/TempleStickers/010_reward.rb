#===============================================================================
# TempleStickers - Ido's visit. Leaving Map113 for Map096 with the reward earned
# (reward_earned?, 003) and staff reward on starts the "temple_messenger" event at
# (11,16): it steps up, says the two boxes, walks south and vanishes. Once per run.
#===============================================================================

module TempleStickers
  TEMPLE_MAP = 113
  TOWN_MAP = 96
  MESSENGER_NAME = "temple_messenger"
  MESSENGER_HOME = [11, 16].freeze
  @messenger_pending = false

  # Ido (roster entry 0); the next roster entry when the player is Ido.
  def self.messenger_for(player_charset, roster)
    roster[0][:charset] == player_charset ? roster[1] : roster[0]
  end

  def self.reward_on?
    Staff.reward_on?(Staff.read(data_dir))
  end

  # Called on map entry; true when the messenger should start now.
  # reward_on may be a proc, read only after the map check passes.
  def self.arm_messenger(old_map_id, new_map_id, run, reward_on)
    return @messenger_pending = false unless old_map_id == TEMPLE_MAP && new_map_id == TOWN_MAP
    @messenger_pending = reward_due?(run, reward_on.respond_to?(:call) ? reward_on.call : reward_on)
  end

  # Consumes the pending flag, so a later Action press on the tile does nothing.
  def self.take_messenger
    pending = @messenger_pending
    @messenger_pending = false
    pending
  end

  def self.player_charset
    ($PokemonGlobal && $PokemonGlobal.desert_player_charset) || $game_player.character_name
  end

  def self.walk(event, *commands)
    pbMoveRoute(event, commands)
    pbWait(0.05) while event.move_route_forcing
  end
end

# Event Script command on the messenger event: pbTempleMessenger(get_self).
def pbTempleMessenger(event)
  ts = TempleStickers
  return false unless event && ts.take_messenger
  entry = ts.messenger_for(ts.player_charset, DesertCharSelect::PLAYABLE)
  event.character_name = entry[:charset]
  event.turn_up
  ts.walk(event, PBMoveRoute::UP)
  DesertTalk.name_key = entry[:name_key] if defined?(DesertTalk)
  pbMessage(_INTL("TEMPLE_REWARD_1"))
  pbMessage(_INTL("TEMPLE_REWARD_2"))
  DesertTalk.clear_speaker if defined?(DesertTalk)
  ts.mark_reward_shown(ts.run)
  ts.walk(event, PBMoveRoute::TURN_DOWN, PBMoveRoute::DOWN, PBMoveRoute::DOWN, PBMoveRoute::DOWN)
  event.character_name = ""
  event.moveto(*ts::MESSENGER_HOME)
  event.turn_down
  true
end

EventHandlers.add(:on_enter_map, :temple_messenger,
  proc { |old_map_id|
    ts = TempleStickers
    next if !$game_map || !$temple_stickers
    next unless ts.arm_messenger(old_map_id, $game_map.map_id, ts.run, -> { ts.reward_on? })
    messenger = $game_map.events.values.find { |e| e.name == ts::MESSENGER_NAME }
    messenger ? messenger.start : ts.take_messenger
  }
)
