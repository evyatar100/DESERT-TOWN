#===============================================================================
# Shira's wedding - art. A1/A2 PNGs are used only at their exact size (SIZES); otherwise a
# drawn fallback of the same layout. Guests are the existing dt_ charsets (D8).
# SIZES must match assets-factory/shira_wedding_placeholders.py.
#===============================================================================

module ShiraWedding
  module Art
    PICTURES = "Graphics/Pictures/ShiraWedding/"
    SIZES = { "shira_poses" => [128, 192], "venue_props" => [384, 96] }.freeze
    CHARSETS = "Graphics/Characters/dt_"
    CHARSET_SIZE = [128, 192].freeze
    FW = 32
    FH = 48
    POSE = [64, 96].freeze
    PROP = 96
    # props cell -> visible rect inside its 96x96 cell (bottom-aligned / bottom-centred, A2)
    PROP_RECTS = [[0, 32, 96, 64], [0, 32, 96, 64], [8, 56, 80, 40], [36, 16, 24, 80]].freeze
    NIGHT = [34, 26, 20].freeze        # #221A14
    INK = [24, 18, 28].freeze
    OUTLINE = [20, 20, 20].freeze      # #141414
    TEXT = [248, 240, 224].freeze
    YELLOW = [248, 216, 104].freeze
    RED = [224, 56, 64].freeze
    GREEN = [104, 200, 112].freeze
    WHITE = [242, 240, 232].freeze
    LILAC = [185, 163, 214].freeze     # #B9A3D6
    LILAC_DARK = [142, 120, 180].freeze
    BULB = [255, 200, 120].freeze
    WIRE = [70, 56, 44].freeze
    FLOOR = [[60, 40, 70], [40, 28, 52]].freeze
    WOOD = [122, 82, 48].freeze
    LIGHTS = [[224, 64, 112], [64, 160, 240], [96, 224, 112], [248, 216, 104]].freeze
    SKIN = [216, 168, 135].freeze
    HAIR = [46, 36, 32].freeze
    SUIT = [30, 30, 34].freeze
    BOW = [216, 52, 60].freeze
    GREY = [96, 96, 104].freeze
    CAPSULES = [[96, 140, 200], [200, 120, 96], [120, 180, 120], [200, 180, 96]].freeze

    def self.color(rgb, alpha = 255) = Color.new(rgb[0], rgb[1], rgb[2], alpha)

    def self.load_exact(path, size, tag)
      found = defined?(pbResolveBitmap) ? pbResolveBitmap(path) : nil
      return nil unless found
      bmp = Bitmap.new(found)
      return bmp if [bmp.width, bmp.height] == size
      echoln("[ShiraWedding] #{tag} is #{bmp.width}x#{bmp.height}, want #{size.join('x')}: fallback") if defined?(echoln)
      bmp.dispose
      nil
    end

    def self.picture(name) = load_exact(PICTURES + name, SIZES[name], name)

    # Always a bitmap of the SIZES layout: the PNG, or the drawn fallback.
    def self.sheet(name) = picture(name) || send("fallback_#{name}")

    # A guest's 128x192 charset, or a capsule sheet of the same layout.
    def self.charset(id, tint = 0) = load_exact(CHARSETS + id, CHARSET_SIZE, "dt_#{id}") || fallback_charset(tint)

    #--- primitives -------------------------------------------------------------
    def self.disc(bmp, cx, cy, r, rgb, alpha = 255)
      (-r..r).each do |dy|
        w = Math.sqrt(r * r - dy * dy).floor
        bmp.fill_rect(cx - w, cy + dy, w * 2 + 1, 1, color(rgb, alpha))
      end
    end

    def self.box(bmp, x, y, w, h, rgb, edge = OUTLINE, t = 2, alpha = 255)
      bmp.fill_rect(x, y, w, h, color(edge, alpha))
      bmp.fill_rect(x + t, y + t, w - 2 * t, h - 2 * t, color(rgb, alpha))
    end

    def self.frame_rect(bmp, x, y, w, h, rgb, t = 2)
      [[x, y, w, t], [x, y + h - t, w, t], [x, y, t, h], [x + w - t, y, t, h]].each { |r| bmp.fill_rect(*r, color(rgb)) }
    end

    def self.heart(bmp, x, y, s, rgb)
      disc(bmp, x + s, y + s, s, rgb)
      disc(bmp, x + 3 * s, y + s, s, rgb)
      (0..2 * s).each { |i| bmp.fill_rect(x + i, y + s + i, [4 * s + 1 - 2 * i, 1].max, 1, color(rgb)) }
    end

    #--- fallbacks (same layout as the PNGs) ---------------------------------------
    def self.capsule(bmp, x, y, w, h, body)
      disc(bmp, x + w / 2, y + h / 4, w / 4 + 1, OUTLINE)
      disc(bmp, x + w / 2, y + h / 4, w / 4, SKIN)
      box(bmp, x + w / 4, y + h / 2 - 2, w / 2, h / 2, body)
    end

    def self.fallback_charset(tint)
      bmp = Bitmap.new(*CHARSET_SIZE)
      4.times { |f| 4.times { |r| capsule(bmp, f * FW + 4, r * FH + 6 - (f.odd? ? 2 : 0), 24, 40, CAPSULES[tint % 4]) } }
      bmp
    end

    def self.fallback_shira_poses
      bmp = Bitmap.new(*SIZES["shira_poses"])
      4.times do |i|
        x = (i % 2) * POSE[0]
        y = (i / 2) * POSE[1]
        capsule(bmp, x + 8, y + 10, 48, 84, SUIT)
        disc(bmp, x + 32, y + 12, 6, HAIR)            # the bun
        disc(bmp, x + 40, y + 10, 3, BOW)             # the bow
        box(bmp, x + 40, y + 52, 14, 16, LILAC, LILAC_DARK) if i == 2
      end
      bmp
    end

    def self.fallback_venue_props
      bmp = Bitmap.new(*SIZES["venue_props"])
      box(bmp, 8, 56, 80, 40, GREY)                                  # DJ booth
      [[20, 44], [76, 44]].each { |cx, cy| disc(bmp, cx, cy, 12, OUTLINE); disc(bmp, cx, cy, 8, GREY) }
      box(bmp, PROP, 48, 96, 48, WOOD)                               # bar
      box(bmp, 2 * PROP + 8, 60, 80, 36, WHITE)                      # banquet table
      box(bmp, 3 * PROP + 44, 16, 8, 80, WIRE)                       # lamp post
      disc(bmp, 3 * PROP + 48, 24, 10, YELLOW)
      bmp
    end

    #--- procedural UI --------------------------------------------------------------
    def self.background(w, h, t = 0)
      bmp = Bitmap.new(w, h)
      bmp.fill_rect(0, 0, w, h, color(NIGHT))
      bmp.fill_rect(0, 30, w, 1, color(WIRE))
      (0...16).each { |i| disc(bmp, 16 + i * 32, 32 + (i.odd? ? 1 : 0), 3, BULB) }
      bmp
    end

    def self.dance_floor(phase)
      bmp = Bitmap.new(144, 64)
      (0...9).each do |cx|
        (0...4).each do |cy|
          rgb = (cx + cy + phase).even? ? FLOOR[0] : LIGHTS[(cx + cy + phase) % LIGHTS.length]
          bmp.fill_rect(cx * 16, cy * 16, 16, 16, color(rgb, (cx + cy + phase).even? ? 255 : 150))
        end
      end
      frame_rect(bmp, 0, 0, 144, 64, OUTLINE)
      bmp
    end

    def self.kids_table(bmp)
      box(bmp, 200, 268, 112, 32, LILAC, OUTLINE)
      bmp.fill_rect(204, 272, 104, 4, color(WHITE))
      disc(bmp, 216, 246, 7, RED)                       # the balloon
      bmp.fill_rect(216, 253, 1, 15, color(OUTLINE))
    end

    def self.badge
      bmp = Bitmap.new(14, 16)
      disc(bmp, 7, 7, 7, OUTLINE)
      disc(bmp, 7, 7, 6, RED)
      bmp.fill_rect(6, 2, 3, 7, color(WHITE))
      bmp.fill_rect(6, 11, 3, 2, color(WHITE))
      bmp
    end

    def self.cursor
      bmp = Bitmap.new(36, 52)
      frame_rect(bmp, 0, 0, 36, 52, YELLOW, 2)
      bmp
    end

    def self.glow
      bmp = Bitmap.new(36, 52)
      bmp.fill_rect(0, 0, 36, 52, color(YELLOW, 90))
      bmp
    end

    def self.confetti(bmp, seed)
      rng = Random.new(seed)
      60.times { bmp.fill_rect(rng.rand(bmp.width), rng.rand(bmp.height), 3, 3, color(LIGHTS[rng.rand(4)])) }
    end

    # The map balloon in :done (no heart animation exists in Animations.rxdata).
    def self.heart_balloon
      bmp = Bitmap.new(20, 18)
      heart(bmp, 1, 1, 4, OUTLINE)
      heart(bmp, 2, 2, 3, RED)
      bmp
    end
  end
end
