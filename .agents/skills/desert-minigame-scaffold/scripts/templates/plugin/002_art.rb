#===============================================================================
# __NAME__ - art. Each PNG is used only at its exact size (SIZES); otherwise a drawn
# fallback of the same layout. SIZES must match assets-factory/__SNAKE___placeholders.py.
#===============================================================================

module __NAME__
  module Art
    PICTURES = "Graphics/Pictures/__NAME__/"
    SIZES = { "title" => [256, 96], "card_win" => [256, 192], "card_lose" => [256, 192] }.freeze
    INK = [24, 18, 28].freeze
    TEXT = [248, 240, 224].freeze
    ACCENT = [216, 138, 59].freeze

    def self.color(rgb, alpha = 255)
      Color.new(rgb[0], rgb[1], rgb[2], alpha)
    end

    def self.picture(name)
      path = defined?(pbResolveBitmap) ? pbResolveBitmap(PICTURES + name) : nil
      return nil unless path
      bmp = Bitmap.new(path)
      return bmp if [bmp.width, bmp.height] == SIZES[name]
      echoln("[__NAME__] #{name}.png is #{bmp.width}x#{bmp.height}, want #{SIZES[name].join('x')}: fallback") if defined?(echoln)
      bmp.dispose
      nil
    end

    # Always a bitmap of the SIZES layout: the PNG, or the drawn fallback.
    def self.sheet(name)
      picture(name) || fallback(name)
    end

    def self.fallback(name)
      w, h = SIZES.fetch(name)
      bmp = Bitmap.new(w, h)
      bmp.fill_rect(0, 0, w, h, color(ACCENT))
      bmp.fill_rect(2, 2, w - 4, h - 4, color(INK))
      bmp
    end
  end
end
