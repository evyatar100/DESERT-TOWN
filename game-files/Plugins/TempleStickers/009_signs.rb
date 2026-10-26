#===============================================================================
# TempleStickers - fact signs. Each sign shows its two boxes (no name plate) and
# gives its own sticker the first time it is read in a run.
#===============================================================================

module TempleStickers
  # Shows the sticker's art above the message box while the block runs.
  def self.with_sticker_image(sticker_id)
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 99_999
    sprite = Sprite.new(viewport)
    sprite.bitmap = Art.bitmap(sticker_id)   # cached by Art; not disposed here
    sprite.x = (Graphics.width - Art::SIZE) / 2
    sprite.y = Graphics.height - 96 - Art::SIZE - 8
    yield
  ensure
    sprite.dispose if sprite && !sprite.disposed?
    viewport.dispose if viewport && !viewport.disposed?
  end
end

# Event Script command: pbTempleSign("KUSAMA_DOT"), one per sign tile.
def pbTempleSign(sticker_id)
  id = TempleStickers.canonical(sticker_id.to_s.upcase)
  unless TempleStickers::STICKERS.key?(id)
    echoln("[TempleStickers] unknown sign id: #{sticker_id}") if defined?(echoln)
    return false
  end
  DesertTalk.clear_speaker if defined?(DesertTalk)
  pbMessage(_INTL(TempleStickers.sign_key(id, 1)))
  pbMessage(_INTL(TempleStickers.sign_key(id, 2)))
  return true unless TempleStickers.read_sign(TempleStickers.run, id) == :sticker
  TempleStickers.with_sticker_image(id) { pbMessage(_INTL("TEMPLE_GOT_STICKER")) }
  true
end
