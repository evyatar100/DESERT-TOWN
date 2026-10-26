#===============================================================================
# TempleStickers - placeholder sticker art: a coloured shape with a white
# die-cut border and a dark outline, drawn with Bitmap. Real sheets come later.
#===============================================================================

module TempleStickers
  module Art
    SIZE = 48
    WHITE = [242, 236, 220].freeze
    DARK = [40, 32, 28].freeze
    @cache = {}

    # True when (dx, dy) from the centre is inside the shape grown by g px.
    def self.inside?(shape, dx, dy, g)
      case shape
      when :circle, :ring then dx * dx + dy * dy <= (15 + g)**2
      when :square        then dx.abs <= 13 + g && dy.abs <= 13 + g
      when :diamond       then dx.abs + dy.abs <= 17 + g
      when :triangle      then dy >= -15 - g && dy <= 12 + g && dx.abs <= (dy + 15 + g) * 0.6
      when :blob          then (dx / (17.0 + g))**2 + (dy / (12.0 + g))**2 <= 1.0
      else false
      end
    end

    def self.pixel_kind(shape, dx, dy)
      if inside?(shape, dx, dy, 0)
        return :white if shape == :ring && dx * dx + dy * dy <= 49
        return :color
      end
      return :white if inside?(shape, dx, dy, 3)
      return :dark if inside?(shape, dx, dy, 4)
      nil
    end

    def self.bitmap(sticker_id)
      bmp = @cache[sticker_id]
      return bmp if bmp && !bmp.disposed?
      spec = STICKERS[sticker_id]
      bmp = Bitmap.new(SIZE, SIZE)
      colors = { color: Color.new(*spec[:color]), white: Color.new(*WHITE), dark: Color.new(*DARK) }
      half = SIZE / 2
      SIZE.times do |y|
        SIZE.times do |x|
          kind = pixel_kind(spec[:shape], x - half, y - half)
          bmp.set_pixel(x, y, colors[kind]) if kind
        end
      end
      @cache[sticker_id] = bmp
    end
  end
end
