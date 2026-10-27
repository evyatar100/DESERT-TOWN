#===============================================================================
# Temple hoop - scene art. Backdrop and ball are procedural; the hoop is Adi's
# hoop_big.png / hoop_front.png, or a drawn placeholder when they are missing.
#===============================================================================

module TempleHoop
  module Art
    PICTURES = "Graphics/Pictures/TempleHoop/"
    WALL_TOP = [26, 20, 32].freeze       # #1A1420
    WALL_BOTTOM = [42, 32, 48].freeze    # #2A2030
    FLOOR = [58, 46, 42].freeze          # #3A2E2A
    FLOOR_LINE = [92, 76, 66].freeze
    FLOOR_Y = 316
    BALL = [216, 138, 59].freeze         # #D88A3B
    SEAM = [40, 32, 28].freeze           # #28201C
    BALL_FRAMES = 4
    HOOP_W = 144
    HOOP_H = 336

    def self.color(rgb, alpha = 255)
      Color.new(rgb[0], rgb[1], rgb[2], alpha)
    end

    def self.mix(a, b, s)
      a.each_index.map { |i| (a[i] + (b[i] - a[i]) * s).round }
    end

    # Bitmap from Graphics/Pictures/TempleHoop/<name>.png, or nil when it is missing.
    def self.picture(name)
      path = defined?(pbResolveBitmap) ? pbResolveBitmap(PICTURES + name) : nil
      path ? Bitmap.new(path) : nil
    end

    def self.backdrop
      w, h = TempleHoopRules::SCREEN_W, TempleHoopRules::SCREEN_H
      bmp = Bitmap.new(w, h)
      FLOOR_Y.times { |y| bmp.fill_rect(0, y, w, 1, color(mix(WALL_TOP, WALL_BOTTOM, y / FLOOR_Y.to_f))) }
      line = color([0, 0, 0], 40)
      (16...FLOOR_Y).step(16) do |y|
        bmp.fill_rect(0, y, w, 1, line)
        offset = (y / 16).even? ? 0 : 16
        (offset...w).step(32) { |x| bmp.fill_rect(x, y - 15, 1, 15, line) }
      end
      bmp.fill_rect(0, FLOOR_Y, w, h - FLOOR_Y, color(FLOOR))
      bmp.fill_rect(0, FLOOR_Y, w, 2, color(mix(FLOOR, [0, 0, 0], 0.4)))
      bmp.fill_rect(300, 352, w - 300, 2, color(FLOOR_LINE))
      bmp
    end

    # 4 rotation frames side by side, 20x20 each: orange disc, 1 px outline, 2 seam curves.
    def self.ball_frames
      d = TempleHoopRules::BALL_R * 2
      bmp = Bitmap.new(d * BALL_FRAMES, d)
      r = d / 2.0 - 0.5
      BALL_FRAMES.times do |f|
        a = f * Math::PI / (2 * BALL_FRAMES)
        d.times do |py|
          d.times do |px|
            x, y = px - r, py - r
            dist = Math.sqrt(x * x + y * y)
            next if dist > r + 0.5
            u = x * Math.cos(a) + y * Math.sin(a)
            v = -x * Math.sin(a) + y * Math.cos(a)
            seam = [-1, 1].any? { |s| (Math.sqrt((u - s * 1.7 * r)**2 + v * v) - 1.3 * r).abs < 0.7 }
            rgb = dist > r - 0.6 || seam || u.abs < 0.5 ? SEAM : BALL
            bmp.set_pixel(f * d + px, py, color(rgb))
          end
        end
      end
      bmp
    end

    # Same canvas and rim spot as hoop_big.png (rim spot from the rules).
    def self.placeholder_hoop
      bmp = Bitmap.new(HOOP_W, HOOP_H)
      bmp.fill_rect(40, 150, 24, HOOP_H - 150, color([120, 120, 128]))
      bmp.fill_rect(14, 8, 116, 136, color([40, 40, 52]))
      bmp.fill_rect(16, 10, 112, 132, color([236, 240, 244]))
      bmp.fill_rect(54, 70, 40, 2, color([200, 60, 40]))
      ellipse(bmp, *TempleHoopRules::RIM_ART, 30, 18, color([226, 96, 40]))
      bmp
    end

    def self.ellipse(bmp, cx, cy, hw, hh, col)
      0.step(359, 3) do |deg|
        rad = deg * Math::PI / 180
        bmp.fill_rect((cx + hw * Math.cos(rad)).round - 1, (cy + hh * Math.sin(rad)).round - 1, 2, 2, col)
      end
    end
  end
end
