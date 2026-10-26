#===============================================================================
# TempleStickers - small UI helpers shared by the keyboard and board scenes.
#===============================================================================

module TempleStickers
  TEXT_BASE = [248, 240, 224].freeze
  TEXT_SHADOW = [40, 32, 24].freeze
  INK = [40, 32, 28].freeze
  INK_SHADOW = [214, 204, 184].freeze
  PAPER = [239, 233, 218].freeze

  def self.color(rgb)
    Color.new(*rgb)
  end

  def self.hebrew?(text)
    text.is_a?(String) && text.match?(/[֐-׿]/)
  end

  # Draws through the Hebrew hook; :auto puts Hebrew on the right.
  def self.draw_text(bmp, x, y, w, h, text, base, shadow, align = :auto)
    return if text.nil? || text.empty?
    align = hebrew?(text) ? 2 : 0 if align == :auto
    pbDrawShadowText(bmp, x, y, w, h, text, color(base), color(shadow), align)
  end

  # Fades the map BGM for the block and restores it after. Nested calls are no-ops.
  def self.silenced
    playing = $game_system && $game_system.respond_to?(:getPlayingBGM) ? $game_system.getPlayingBGM : nil
    pbBGMFade(0.8) if playing
    yield
  ensure
    pbBGMPlay(playing) if playing
  end

  def self.raw_color?(color, reader = :triggerex?)
    return false unless defined?(DesertTownControls) && Input.respond_to?(reader)
    Input.send(reader, DesertTownControls.key(color))
  end

  # White + Green together (either pressed while the other is held). Not secret.
  def self.staff_combo?
    (raw_color?(:white) && raw_color?(:green, :pressex?)) ||
      (raw_color?(:green) && raw_color?(:white, :pressex?))
  end
end
