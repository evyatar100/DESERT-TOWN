#===============================================================================
# Arm wrestling - art. Adi's 3 PNGs when present at their exact size, otherwise a
# drawn fallback for each; every FX bitmap (rings, "!", button, puff, vignette) is drawn.
#===============================================================================

module ArmWrestle
  module Art
    PICTURES = "Graphics/Pictures/ArmWrestle/"
    SIZES = { "aw_backdrop" => [256, 192], "aw_shirpaz" => [288, 192], "aw_arms" => [1232, 728] }.freeze
    SCALE = 2                      # native art is shown at x2
    FACE_CELL = 96
    FACE_COLS = 3
    ARM_CELL = [176, 104].freeze
    ARM_COLS = 7
    ARM_PIVOT = [88, 96].freeze
    BUST_CHARSET = "Graphics/Characters/dt_670f79e3"
    BUST_FRAME = [0, 0, 32, 48].freeze   # front-facing frame of the map sprite
    BUST_ZOOM = 4
    FALLBACK_ARMS = [44, 92].freeze
    FALLBACK_PIVOT = [22, 90].freeze
    TARGET_R = 18
    RING_MAX = 58
    RING_STEP = 2
    RING_BOX = (RING_MAX + 3) * 2
    SCREEN = [512, 384].freeze
    TABLE_Y = 240
    PADS = [[88, 300], [424, 300]].freeze
    # Palette lock (spec).
    OUTLINE = [42, 42, 42].freeze
    SKIN = [210, 145, 103].freeze
    SKIN_SHADE = [168, 107, 72].freeze
    INK = [58, 58, 74].freeze
    WOOD = [138, 90, 58].freeze
    WOOD_DARK = [94, 59, 38].freeze
    WOOD_LIGHT = [181, 132, 78].freeze
    SKY_TOP = [58, 42, 74].freeze
    SKY_LOW = [216, 138, 59].freeze
    LIGHT = [248, 216, 104].freeze
    PAD = [181, 72, 63].freeze
    SLEEVE = [79, 114, 184].freeze
    BAND = [95, 154, 108].freeze
    CLOTH = [120, 92, 80].freeze
    PLAYA = [196, 150, 104].freeze
    WHITE = [248, 240, 224].freeze

    def self.color(rgb, alpha = 255)
      Color.new(rgb[0], rgb[1], rgb[2], alpha)
    end

    def self.mix(a, b, s)
      a.each_index.map { |i| (a[i] + (b[i] - a[i]) * s).round }
    end

    # The PNG when it exists at its exact canvas size; nil otherwise (the caller falls back).
    def self.picture(name)
      path = defined?(pbResolveBitmap) ? pbResolveBitmap(PICTURES + name) : nil
      return nil unless path
      bmp = Bitmap.new(path)
      return bmp if [bmp.width, bmp.height] == SIZES[name]
      echoln("[ArmWrestle] #{name}.png is #{bmp.width}x#{bmp.height}, want #{SIZES[name].join('x')}: fallback") if defined?(echoln)
      bmp.dispose
      nil
    end

    def self.face_rect(face)
      i = ArmWrestleRules::FACES.index(face) || 0
      [(i % FACE_COLS) * FACE_CELL, (i / FACE_COLS) * FACE_CELL, FACE_CELL, FACE_CELL]
    end

    def self.arm_rect(frame)
      [(frame % ARM_COLS) * ARM_CELL[0], (frame / ARM_COLS) * ARM_CELL[1], *ARM_CELL]
    end

    # Clasped hands on screen for a balance (follows the arm rotation around the elbow pivot).
    def self.hands_at(b, pivot, reach)
      rad = ArmWrestleRules.angle(b) * Math::PI / 180
      [(pivot[0] + reach * Math.sin(rad)).round, (pivot[1] - reach * Math.cos(rad)).round]
    end

    def self.bust_fallback
      path = defined?(pbResolveBitmap) ? pbResolveBitmap(BUST_CHARSET) : nil
      path ? Bitmap.new(path) : nil
    end

    #--- procedural fallbacks -------------------------------------------------
    def self.backdrop
      w, h = SCREEN
      bmp = Bitmap.new(w, h)
      TABLE_Y.times { |y| bmp.fill_rect(0, y, w, 1, color(mix(SKY_TOP, SKY_LOW, y / TABLE_Y.to_f))) }
      bmp.fill_rect(0, 196, w, TABLE_Y - 196, color(PLAYA))
      bmp.fill_rect(0, 0, w, 34, color(CLOTH))
      bmp.fill_rect(0, 34, w, 2, color(OUTLINE))
      [[0, 256], [256, 512]].each do |x0, x1|
        (x0...x1).step(4) do |x|
          s = (x - x0) / (x1 - x0).to_f
          y = 44 + (4 * 26 * s * (1 - s)).round
          bmp.fill_rect(x, y, 4, 1, color(OUTLINE))
          bmp.fill_rect(x, y + 1, 3, 3, color(LIGHT)) if (x - x0) % 32 == 16
        end
      end
      bmp.fill_rect(0, TABLE_Y, w, h - TABLE_Y, color(WOOD))
      bmp.fill_rect(0, TABLE_Y, w, 4, color(WOOD_LIGHT))
      bmp.fill_rect(0, TABLE_Y + 4, w, 2, color(WOOD_DARK))
      (TABLE_Y + 22...h).step(22) { |y| bmp.fill_rect(0, y, w, 1, color(WOOD_DARK)) }
      PADS.each do |cx, cy|
        bmp.fill_rect(cx - 50, cy - 20, 100, 40, color(OUTLINE))
        bmp.fill_rect(cx - 48, cy - 18, 96, 36, color(PAD))
        bmp.fill_rect(cx - 48, cy - 18, 96, 4, color(mix(PAD, WHITE, 0.3)))
      end
      bmp
    end

    # Two upright forearms meeting at the elbow pivot, hands clasped on top (shown at x2, rotated).
    def self.arms
      w, h = FALLBACK_ARMS
      bmp = Bitmap.new(w, h)
      [[4, SKIN], [24, SKIN]].each do |x, rgb|
        bmp.fill_rect(x, 16, 16, h - 16, color(OUTLINE))
        bmp.fill_rect(x + 2, 18, 12, h - 20, color(rgb))
        bmp.fill_rect(x + 10, 18, 4, h - 20, color(SKIN_SHADE))
      end
      bmp.fill_rect(6, h - 16, 12, 12, color(SLEEVE))        # the player's rolled sleeve
      bmp.fill_rect(6, 26, 12, 4, color(BAND))               # and wristband
      [[30, 40], [28, 56], [32, 66]].each { |x, y| bmp.fill_rect(x, y, 5, 2, color(INK)) }   # her tattoos
      bmp.fill_rect(6, 0, 32, 22, color(OUTLINE))
      bmp.fill_rect(8, 2, 28, 18, color(SKIN))
      [12, 18, 24, 30].each { |x| bmp.fill_rect(x, 4, 1, 10, color(SKIN_SHADE)) }
      bmp
    end

    #--- FX ----------------------------------------------------------------------
    def self.circle(bmp, cx, cy, r, rgb, thick = 2, alpha = 255)
      steps = (2 * Math::PI * r).ceil
      steps.times do |i|
        a = 2 * Math::PI * i / steps
        bmp.fill_rect((cx + r * Math.cos(a)).round - thick / 2, (cy + r * Math.sin(a)).round - thick / 2, thick, thick, color(rgb, alpha))
      end
    end

    def self.disc(bmp, cx, cy, r, rgb)
      (-r..r).each do |dy|
        half = Math.sqrt(r * r - dy * dy).round
        bmp.fill_rect(cx - half, cy + dy, half * 2 + 1, 1, color(rgb))
      end
    end

    def self.ring_count
      (RING_MAX - TARGET_R) / RING_STEP + 1
    end

    # Gold rings from TARGET_R to RING_MAX, one RING_BOX square cell each, left to right.
    def self.ring_strip
      bmp = Bitmap.new(RING_BOX * ring_count, RING_BOX)
      ring_count.times do |i|
        c = RING_BOX * i + RING_BOX / 2
        circle(bmp, c + 1, RING_BOX / 2 + 1, TARGET_R + i * RING_STEP, OUTLINE, 3)
        circle(bmp, c, RING_BOX / 2, TARGET_R + i * RING_STEP, LIGHT, 3)
      end
      bmp
    end

    def self.ring_index(frac)
      (frac.clamp(0.0, 1.0) * (ring_count - 1)).round
    end

    def self.target_ring
      bmp = Bitmap.new(RING_BOX, RING_BOX)
      circle(bmp, RING_BOX / 2, RING_BOX / 2, TARGET_R, OUTLINE, 4)
      circle(bmp, RING_BOX / 2, RING_BOX / 2, TARGET_R, WHITE, 2, 220)
      bmp
    end

    # Yellow "!" with a dark outline, 20x44.
    def self.bang
      bmp = Bitmap.new(20, 44)
      bmp.fill_rect(4, 0, 12, 30, color(OUTLINE))
      bmp.fill_rect(6, 2, 8, 26, color(LIGHT))
      bmp.fill_rect(4, 32, 12, 12, color(OUTLINE))
      bmp.fill_rect(6, 34, 8, 8, color(LIGHT))
      bmp
    end

    # A cabinet colour button: dark rim, coloured face, a small highlight.
    def self.button(rgb, r = 13)
      bmp = Bitmap.new(r * 2 + 4, r * 2 + 4)
      disc(bmp, r + 2, r + 2, r + 1, OUTLINE)
      disc(bmp, r + 2, r + 2, r - 1, rgb)
      disc(bmp, r - 2, r - 2, 3, mix(rgb, WHITE, 0.6))
      bmp
    end

    def self.puff
      bmp = Bitmap.new(24, 24)
      disc(bmp, 12, 12, 10, mix(PLAYA, WHITE, 0.3))
      disc(bmp, 9, 9, 4, WHITE)
      bmp
    end

    # Red edges fading toward the centre (opacity pulses on the edge).
    def self.vignette
      w, h = SCREEN
      bmp = Bitmap.new(w, h)
      40.times do |i|
        c = color([200, 30, 30], (40 - i) * 5)
        bmp.fill_rect(i, i, w - 2 * i, 1, c)
        bmp.fill_rect(i, h - 1 - i, w - 2 * i, 1, c)
        bmp.fill_rect(i, i + 1, 1, h - 2 * i - 2, c)
        bmp.fill_rect(w - 1 - i, i + 1, 1, h - 2 * i - 2, c)
      end
      bmp
    end
  end
end
