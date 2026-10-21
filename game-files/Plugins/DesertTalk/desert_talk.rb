#===============================================================================
# DesertTalk — character name plate + dialogue lookup
#===============================================================================
# pbDesertTalk(id) looks up NAME_/MSG_ keys, shows a right-aligned name plate
# above the message window (or below it when the box sits in the upper half),
# then calls pbMessage. The plate is disposed when the message closes.
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
  DesertTalk.name_key = char[:name_key]
  begin
    pbMessage(_INTL(line_key))
  ensure
    DesertTalk.clear_name
    DesertTalk.dispose_name_window
  end
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
