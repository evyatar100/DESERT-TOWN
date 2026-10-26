#===============================================================================
# TempleStickers - sticker art. Real art: Graphics/Pictures/TempleStickers/
# <honoree>.png, 96x96, 48 px cells row-major, frames 0-2 in STICKERS order
# (frame 3 is the reserve). Missing sheet: a placeholder shape drawn here.
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

    SHEET_DIR = "Graphics/Pictures/TempleStickers/"

    # [x, y, w, h] of the sticker's cell on its honoree's sheet.
    def self.sheet_rect(sticker_id)
      i = TempleStickers.stickers_for(STICKERS[sticker_id][:honoree]).index(sticker_id)
      [SIZE * (i % 2), SIZE * (i / 2), SIZE, SIZE]
    end

    # The sheet cell as its own bitmap; nil when the sheet is missing or unreadable.
    def self.sheet_bitmap(sticker_id)
      file = pbResolveBitmap(SHEET_DIR + STICKERS[sticker_id][:honoree])
      return nil unless file
      sheet = Bitmap.new(file)
      bmp = Bitmap.new(SIZE, SIZE)
      bmp.blt(0, 0, sheet, Rect.new(*sheet_rect(sticker_id)))
      bmp
    rescue StandardError
      nil
    ensure
      sheet.dispose if sheet && !sheet.disposed?
    end

    def self.bitmap(sticker_id)
      bmp = @cache[sticker_id]
      return bmp if bmp && !bmp.disposed?
      bmp = sheet_bitmap(sticker_id)
      return @cache[sticker_id] = bmp if bmp
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
