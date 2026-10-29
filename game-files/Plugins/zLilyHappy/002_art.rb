#===============================================================================
# LilyHappy - art. Each PNG is used only at its exact size (SIZES); otherwise a drawn
# fallback (wheel_bg) or nothing (lily_faces). SIZES must match assets-factory/lily_happy_placeholders.py.
# Hearts, bubbles, chevron, floats and the heart balloon are procedural.
#===============================================================================

module LilyHappy
  module Art
    PICTURES = "Graphics/Pictures/LilyHappy/"
    SIZES = { "lily_faces" => [512, 128], "wheel_bg" => [512, 384] }.freeze
    FACES = %i[grumpy curious giggle beam].freeze
    FACE = 128
    CHARSETS = "Graphics/Characters/dt_"
    CHARSET_SIZE = [128, 192].freeze
    FW = 32
    FH = 48
    RING = [256, 172, 100].freeze      # background ring centre and radius (D8)
    INK = [24, 18, 28].freeze
    OUTLINE = [20, 20, 20].freeze
    TEXT = [248, 240, 224].freeze
    RED = [224, 56, 64].freeze
    GREEN = [104, 200, 112].freeze
    YELLOW = [248, 216, 104].freeze
    WHITE = [242, 240, 232].freeze
    WOOD = [122, 82, 48].freeze
    WOOD_DARK = [78, 52, 32].freeze
    SKY = [[22, 18, 40], [58, 34, 52]].freeze
    SAND = [[84, 60, 50], [46, 34, 34]].freeze
    PHASE_RGB = [[104, 200, 112], [248, 176, 72], [224, 56, 64]].freeze
    SKIN = [216, 168, 135].freeze
    CAPSULES = [[96, 140, 200], [200, 120, 96], [120, 180, 120], [200, 180, 96], [170, 120, 200], [90, 170, 170]].freeze

    def self.color(rgb, alpha = 255) = Color.new(rgb[0], rgb[1], rgb[2], alpha)

    def self.load_exact(path, size, tag)
      found = defined?(pbResolveBitmap) ? pbResolveBitmap(path) : nil
      return nil unless found
      bmp = Bitmap.new(found)
      return bmp if [bmp.width, bmp.height] == size
      echoln("[LilyHappy] #{tag} is #{bmp.width}x#{bmp.height}, want #{size.join('x')}: fallback") if defined?(echoln)
      bmp.dispose
      nil
    end

    def self.picture(name) = load_exact(PICTURES + name, SIZES[name], name)

    # The backdrop PNG, or the procedural ring of the same layout.
    def self.background = picture("wheel_bg") || fallback_wheel_bg

    # nil when missing or the wrong size: the payoff then shows no portrait.
    def self.faces = picture("lily_faces")

    # A seat's 128x192 charset, or a capsule sheet of the same layout.
    def self.charset(id, tint = 0) = load_exact(CHARSETS + id, CHARSET_SIZE, "dt_#{id}") || fallback_charset(tint)

    #--- primitives ---------------------------------------------------------------
    def self.disc(bmp, cx, cy, r, rgb, alpha = 255)
      (-r..r).each do |dy|
        w = Math.sqrt(r * r - dy * dy).floor
        bmp.fill_rect(cx - w, cy + dy, w * 2 + 1, 1, color(rgb, alpha))
      end
    end

    # Copy of zShiraWedding's heart: two discs and a tapering point.
    def self.heart(bmp, x, y, s, rgb)
      disc(bmp, x + s, y + s, s, rgb)
      disc(bmp, x + 3 * s, y + s, s, rgb)
      (0..2 * s).each { |i| bmp.fill_rect(x + i, y + s + i, [4 * s + 1 - 2 * i, 1].max, 1, color(rgb)) }
    end

    def self.line(bmp, x0, y0, x1, y1, t, rgb)
      n = [(x1 - x0).abs, (y1 - y0).abs].max.ceil
      (0..n).each do |i|
        f = n.zero? ? 0 : i.to_f / n
        bmp.fill_rect((x0 + (x1 - x0) * f).round - t / 2, (y0 + (y1 - y0) * f).round - t / 2, t, t, color(rgb))
      end
    end

    #--- fallbacks ------------------------------------------------------------------
    def self.fallback_wheel_bg
      w, h = SIZES["wheel_bg"]
      bmp = Bitmap.new(w, h)
      horizon = 150
      gradient(bmp, 0, horizon, SKY)
      gradient(bmp, horizon, h - horizon, SAND)
      cx, cy, r = RING
      6.times do |i|
        a = (90 - 60 * i) * Math::PI / 180
        line(bmp, cx, cy, cx + (r * Math.cos(a)).round, cy + (r * Math.sin(a)).round, 4, WOOD_DARK)
      end
      ring(bmp, cx, cy, r, 6, WOOD)
      disc(bmp, cx, cy, 26, WOOD_DARK)
      bmp.fill_rect(0, 0, w, 28, color(INK))
      bmp.fill_rect(0, 316, w, h - 316, color(INK))
      bmp
    end

    def self.gradient(bmp, y0, hh, pair)
      hh.times do |i|
        f = i.to_f / [hh - 1, 1].max
        rgb = (0..2).map { |c| (pair[0][c] + (pair[1][c] - pair[0][c]) * f).round }
        bmp.fill_rect(0, y0 + i, bmp.width, 1, color(rgb))
      end
    end

    def self.ring(bmp, cx, cy, r, t, rgb)
      (0...360).step(2) do |d|
        a = d * Math::PI / 180
        bmp.fill_rect(cx + (r * Math.cos(a)).round - t / 2, cy + (r * Math.sin(a)).round - t / 2, t, t, color(rgb))
      end
    end

    def self.fallback_charset(tint)
      bmp = Bitmap.new(*CHARSET_SIZE)
      body = CAPSULES[tint % CAPSULES.size]
      4.times do |row|
        4.times do |col|
          x, y = col * FW, row * FH
          disc(bmp, x + 16, y + 14, 9, OUTLINE)
          disc(bmp, x + 16, y + 14, 8, SKIN)
          bmp.fill_rect(x + 8, y + 24, 16, 22, color(OUTLINE))
          bmp.fill_rect(x + 9, y + 25, 14, 20, color(body))
        end
      end
      bmp
    end

    #--- procedural pieces ---------------------------------------------------------
    def self.heart_icon(full)
      bmp = Bitmap.new(8, 7)
      heart(bmp, 0, 0, 2, full ? RED : OUTLINE)
      heart(bmp, 1, 1, 1, [70, 60, 66]) unless full
      bmp
    end

    # 28x24 speech bubble with "!" (or the half mark) drawn as blocks, no font needed.
    def self.bubble(half)
      bmp = Bitmap.new(28, 24)
      bmp.fill_rect(1, 0, 26, 19, color(OUTLINE))
      bmp.fill_rect(0, 1, 28, 17, color(OUTLINE))
      bmp.fill_rect(2, 2, 24, 15, color(WHITE))
      bmp.fill_rect(8, 19, 6, 2, color(OUTLINE))
      bmp.fill_rect(9, 21, 3, 3, color(OUTLINE))
      bmp.fill_rect(9, 17, 4, 3, color(WHITE))
      if half
        bmp.fill_rect(8, 4, 3, 5, color(RED))
        line(bmp, 18, 4, 10, 15, 2, OUTLINE)
        bmp.fill_rect(16, 10, 5, 2, color(RED))
        bmp.fill_rect(19, 12, 2, 2, color(RED))
        bmp.fill_rect(16, 14, 5, 2, color(RED))
      else
        bmp.fill_rect(12, 3, 4, 9, color(RED))
        bmp.fill_rect(12, 13, 4, 3, color(RED))
      end
      bmp
    end

    def self.chevron
      bmp = Bitmap.new(14, 7)
      7.times { |i| bmp.fill_rect(i, i, 14 - 2 * i, 1, color(YELLOW)) }
      bmp
    end

    # The map balloon over Lily in the payoff (copy of zShiraWedding's).
    def self.heart_balloon
      bmp = Bitmap.new(20, 18)
      heart(bmp, 1, 1, 4, OUTLINE)
      heart(bmp, 2, 2, 3, RED)
      bmp
    end
  end
end
