#===============================================================================
# DesertTalk — character name plate + dialogue lookup
#===============================================================================
# pbDesertTalk(id) looks up the character and shows the default line
# (or an override key) with pbMessage. It does not set or clear the speaker.
#
# pbDesertSpeaker(id) is the per-character setup for the rest of the current
# event: every following message window shows that character's name plate
# until the event's interpreter stops running (see the :on_frame_update
# handler at the bottom of this file). Call it before pbDesertTalk.
#===============================================================================

module DesertTalk
  @@name_key = nil
  @@name_window = nil

  def self.name_key
    return @@name_key
  end

  def self.name_key=(key)
    @@name_key = key
  end

  def self.clear_name
    @@name_key = nil
  end

  def self.start_speaker(character_id)
    char = CHARACTERS[character_id]
    if !char
      raise "Unknown DesertTalk character: #{character_id}"
    end
    @@name_key = char[:name_key]
    return char
  end

  def self.clear_speaker
    clear_name
    dispose_name_window
  end

  def self.dispose_name_window
    if @@name_window && !@@name_window.disposed?
      @@name_window.dispose
    end
    @@name_window = nil
  end

  # Padding so the speech-frame border does not clip the glyphs.
  NAME_PLATE_PAD_X = 32
  NAME_PLATE_PAD_Y = 12

  def self.show_name_plate(msgwindow)
    dispose_name_window
    return if !@@name_key || !msgwindow
    name = _INTL(@@name_key)
    return if !name || name.empty? || name == @@name_key
    namewindow = Window_AdvancedTextPokemon.new(name)
    skin = MessageConfig.pbGetSpeechFrame
    namewindow.setSkin(skin) if skin
    # Size to the name text only (not the message window width).
    namewindow.resizeToFit(namewindow.text, Graphics.width - 32)
    namewindow.width = namewindow.width + NAME_PLATE_PAD_X
    if namewindow.respond_to?(:resizeHeightToFit)
      namewindow.resizeHeightToFit(namewindow.text, namewindow.width)
    end
    namewindow.height = namewindow.height + NAME_PLATE_PAD_Y
    # Outer edge of the message window: above when the box is in the lower half.
    if msgwindow.y >= Graphics.height / 2
      namewindow.y = msgwindow.y - namewindow.height
    else
      namewindow.y = msgwindow.y + msgwindow.height
    end
    # Right-aligned to the message window (Hebrew-friendly).
    namewindow.x = msgwindow.x + msgwindow.width - namewindow.width
    namewindow.x = 0 if namewindow.x < 0
    namewindow.viewport = msgwindow.viewport
    namewindow.z = msgwindow.z
    @@name_window = namewindow
  end
end

def pbDesertTalk(character_id, line_key = nil)
  char = DesertTalk::CHARACTERS[character_id]
  if !char
    raise "Unknown DesertTalk character: #{character_id}"
  end
  line_key = char[:line_key] if !line_key || line_key == ""
  pbMessage(_INTL(line_key))
end

# Set the speaker for every following message in this event. The plate
# clears automatically when the event finishes; call again with another
# id to switch speaker mid-event.
def pbDesertSpeaker(character_id)
  DesertTalk.start_speaker(character_id)
end

if defined?(pbCreateMessageWindow)
  alias desert_talk_pbCreateMessageWindow pbCreateMessageWindow
  def pbCreateMessageWindow(*args)
    msgwindow = desert_talk_pbCreateMessageWindow(*args)
    DesertTalk.show_name_plate(msgwindow) if DesertTalk.name_key
    return msgwindow
  end
end

if defined?(pbDisposeMessageWindow)
  alias desert_talk_pbDisposeMessageWindow pbDisposeMessageWindow
  def pbDisposeMessageWindow(msgwindow)
    DesertTalk.dispose_name_window
    desert_talk_pbDisposeMessageWindow(msgwindow)
  end
end

# A speaker set with pbDesertSpeaker lasts until the event that set it
# finishes. The map interpreter is still running between messages in the
# same event, so the first frame after it stops is the event's end.
if defined?(EventHandlers)
  EventHandlers.add(:on_frame_update, :desert_talk_clear_speaker,
    proc {
      next if !DesertTalk.name_key
      next if defined?($game_temp) && $game_temp && ($game_temp.message_window_showing || $game_temp.in_battle)
      next if defined?(pbMapInterpreterRunning?) && pbMapInterpreterRunning?
      DesertTalk.clear_speaker
    }
  )

  # מומיה hazards use Event Touch, so the player walking into one starts it.
  # The v21 hotfix does not start a normal Event Touch when the event is the
  # one that moves, so a mummy that walks up to the player would not fire.
  # Start it when that mummy is on the player's tile or facing the next tile.
  #
  # Optimized: cache mummy events per map so we skip the full-event scan each
  # frame. The cache rebuilds when $game_map.map_id changes.
  $desert_mummy_cache_map_id = nil
  $desert_mummy_cache_events = []

  EventHandlers.add(:on_frame_update, :desert_mummy_touch,
    proc {
      next unless defined?($game_map) && $game_map && defined?($game_player) && $game_player
      next if defined?($game_temp) && $game_temp && (
        $game_temp.message_window_showing || $game_temp.in_battle || $game_temp.player_transferring
      )
      next if defined?($game_system) && $game_system&.map_interpreter&.running?
      next if defined?(pbMapInterpreterRunning?) && pbMapInterpreterRunning?
      if $game_map.map_id != $desert_mummy_cache_map_id
        $desert_mummy_cache_map_id = $game_map.map_id
        $desert_mummy_cache_events = $game_map.events.values.select { |e|
          e.trigger == 2 && e.name == "dt_1820dc9d"
        }
      end
      next if $desert_mummy_cache_events.empty?
      px = $game_player.x
      py = $game_player.y
      $desert_mummy_cache_events.each do |event|
        next if event.starting || event.jumping?
        same = event.x == px && event.y == py
        nx = event.x + (event.direction == 6 ? 1 : event.direction == 4 ? -1 : 0)
        ny = event.y + (event.direction == 2 ? 1 : event.direction == 8 ? -1 : 0)
        if same || (nx == px && ny == py)
          event.start
          break
        end
      end
    }
  )
end
