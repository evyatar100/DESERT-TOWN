#===============================================================================
# Planetarium - the procedural sky. Every bitmap is built once in initialize;
# update(t) only moves sprites and sets opacity. Scenes come from PlanetRules.
#===============================================================================

module Planet
  class Sky
    R = PlanetRules
    W = 512
    H = 384
    STAR_SPEEDS = [1.5, 3.0, 6.0].freeze   # px/s per parallax layer
    MOON_C = [400, 120].freeze
    NORTH_C = [150, 110].freeze
    SAT_Y = [92, 120].freeze
    WAR_FLASH_AT = 12.0                      # seconds into satellite_war
    DROPOUTS = [[3.0, 3.25], [9.0, 9.2]].freeze

    def initialize(viewport, segs)
      @vp = viewport
      @segs = segs
      @rng = Random.new(1969)
      @all = []
      @shared = []
      build
    rescue StandardError
      dispose   # a half-built sky frees what it already made
      raise
    end

    def dispose
      @all.each do |s|
        next if s.disposed?
        s.bitmap.dispose if s.bitmap && !s.bitmap.disposed? && !@shared.include?(s.bitmap)
        s.dispose
      end
      @shared.each { |b| b.dispose unless b.disposed? }
      @all.clear
    end

    def update(t)
      info = R.scene_info(t, @segs)
      lay = info[:layers]
      update_stars(t, info, lay)
      @exit_glow.opacity = op(lay[:exit_glow], 0.75 + 0.25 * Math.sin(t * 2))
      update_galaxy(t, lay)
      update_moon(t, lay)
      update_north(t, lay)
      update_mars(t, lay)
      update_satellites(t, lay)
      update_horizon(info, lay)
      update_meteors(t, info, lay)
      update_countdown(t)
    end

    #--- update ---------------------------------------------------------------
    def op(level, mul = 1.0)
      ((level || 0.0) * mul * 255).round.clamp(0, 255)
    end

    def age(t, layer)
      R.layer_age(t, @segs, layer)
    end

    def update_stars(t, info, lay)
      fast = info[:drift]
      @planes.each_with_index do |pl, i|
        pl.ox = (t * STAR_SPEEDS[i] * fast).to_i % W
        pl.opacity = op(info[:stars])
      end
      @twinkles.each_with_index do |s, i|
        s.opacity = op(info[:stars], 0.55 + 0.45 * Math.sin(t * (1.3 + i * 0.07) + i))
      end
    end

    def update_galaxy(t, lay)
      @galaxy.angle = -t * 1.5
      @galaxy.opacity = op(lay[:galaxy], 0.8)
    end

    def update_moon(t, lay)
      a = age(t, :moon)
      @moon.opacity = op(lay[:moon])
      @gas.each { |g| g.opacity = op(lay[:gas], 0.5) }
      return if !a
      rise = R.ease(a / 8.0)
      @moon.x = MOON_C[0]
      @moon.y = (H + 60 - (H + 60 - MOON_C[1]) * rise).round
      fl = lay[:flicker] || 0.0
      if fl > 0
        fa = age(t, :flicker) || 0
        drop = DROPOUTS.any? { |lo, hi| fa >= lo && fa < hi }
        @moon.opacity = op(lay[:moon], drop ? 0.2 : 1.0 - fl * (0.25 + 0.2 * Math.sin(t * 9)))
        @moon.zoom_x = @moon.zoom_y = 1.0 + fl * 0.05 * Math.sin(t * 3.1)
      else
        @moon.zoom_x = @moon.zoom_y = 1.0
      end
      @gas.each_with_index do |g, i|
        ang = t * 0.25 + i * Math::PI / 3
        g.x = (@moon.x + Math.cos(ang) * (58 + 10 * Math.sin(t + i))).round
        g.y = (@moon.y + Math.sin(ang) * 40).round
      end
    end

    def update_north(t, lay)
      ang = t * 0.12
      @north.x = (NORTH_C[0] + Math.cos(ang) * 60).round
      @north.y = (NORTH_C[1] + Math.sin(ang) * 60).round
      @north.opacity = op(lay[:north], 0.85 + 0.15 * Math.sin(t * 4))
    end

    def update_mars(t, lay)
      a = age(t, :mars)
      @mars.opacity = op(lay[:mars])
      return if !a
      @mars.x = (-60 + 220 * R.ease(a / 6.0)).round
      @mars.y = 150
    end

    def update_satellites(t, lay)
      a = age(t, :sat)
      @sat.opacity = op(lay[:sat])
      @blink.opacity = (t * 2).to_i.even? ? @sat.opacity : 0
      if a
        @sat.x = [-40 + a * 9, 200].min.round
        @sat.y = SAT_Y[0]
      end
      @blink.x, @blink.y = @sat.x + 2, @sat.y - 9
      la = age(t, :laser)
      @laser.opacity = op(lay[:laser])
      if la
        reach = R.ease(la / 3.0)
        ring = [Math.cos(t * 3) * 14, Math.sin(t * 3) * 9]
        @laser.x = (256 + (@sat.x + ring[0] - 256) * reach).round
        @laser.y = (H - 10 + (@sat.y + ring[1] - H + 10) * reach).round
      end
      update_war(t, lay)
    end

    def update_war(t, lay)
      a = age(t, :sat2)
      @sat2.opacity = op(lay[:sat2])
      @sat2.x = a ? [W + 40 - a * 12, 380].max.round : W + 40
      @sat2.y = SAT_Y[1]
      @missiles.each_with_index do |m, i|
        f = a ? ((a * 0.6 + i / @missiles.length.to_f) % 1.0) : 0
        from, to = i.even? ? [@sat2, @sat] : [@sat, @sat2]
        m.x = (from.x + (to.x - from.x) * f).round
        m.y = (from.y + (to.y - from.y) * f).round
        m.angle = i.even? ? 180 : 0
        m.opacity = a && a > 2 ? op(lay[:missiles], Math.sin(f * Math::PI)) : 0
      end
      war_flash = a && a >= WAR_FLASH_AT && a < WAR_FLASH_AT + R::FLASH ? 1 - (a - WAR_FLASH_AT) / R::FLASH : 0
      @flash_level = war_flash * (lay[:sat2] || 0)
    end

    def update_horizon(info, lay)
      p = info[:progress]
      @red.opacity = op(lay[:red], 0.4 + 0.6 * p)
      @blue.opacity = op(lay[:blue], 0.5 + 0.5 * p)
    end

    def update_meteors(t, info, lay)
      level = lay[:meteors] || 0.0
      war = (((lay[:red] || 0.0) - 0.25) / 0.75).clamp(0.0, 1.0)
      p = info[:progress]
      cap = (1 - war) * (20 + 40 * p) + war * (60 + 160 * p)   # <= 60 while "you can't see them"
      count = (4 + (R::METEORS - 4) * war * p).round
      @meteors.each_with_index do |m, i|
        period = 2.0 + (i * 37 % 40) / 10.0
        f = ((t + i * 0.77) % period) / period
        sx, sy = @meteor_starts[i]
        m.x = (sx - f * 260).round
        m.y = (sy + f * 150).round
        m.opacity = i < count ? (level * cap * Math.sin(f * Math::PI)).round : 0
      end
    end

    def update_countdown(t)
      cd = R.countdown_at(t, @segs)
      if cd
        @digit.bitmap = @digits[cd[0]]
        @digit.opacity = (255 * (1 - cd[1])).round
      else
        @digit.opacity = 0
      end
      burst = R.burst_at(t, @segs)
      flash = burst && burst < R::FLASH ? 1 - burst / R::FLASH : 0
      @flash.opacity = (255 * [flash, @flash_level || 0].max).round
      @sparks.each_with_index do |s, i|
        if burst
          ang = i * 2 * Math::PI / @sparks.length
          rad = 20 + burst * 130
          s.x = (W / 2 + Math.cos(ang) * rad).round
          s.y = (H / 2 + Math.sin(ang) * rad).round
          s.opacity = (255 * (1 - burst / R::SPARKLE)).round
        else
          s.opacity = 0
        end
      end
    end

    #--- build ----------------------------------------------------------------
    def col(r, g, b, a = 255)
      Color.new(r, g, b, a)
    end

    def sprite(bitmap, z, x = 0, y = 0, center = false)
      s = Sprite.new(@vp)
      s.bitmap = bitmap
      s.z = z
      s.x, s.y = x, y
      if center
        s.ox = bitmap.width / 2
        s.oy = bitmap.height / 2
      end
      s.opacity = 0
      @all << s
      s
    end

    # Filled circle, row by row.
    def circle(bmp, cx, cy, r, color)
      (-r..r).each do |dy|
        half = Math.sqrt([r * r - dy * dy, 0].max).round
        bmp.fill_rect(cx - half, cy + dy, half * 2 + 1, 1, color)
      end
    end

    # Soft glow: big faint circles first, smaller brighter ones over them.
    def glow(bmp, cx, cy, r, rgb, max_a)
      r.step(1, -2) do |rr|
        a = (max_a * (1 - rr.to_f / r)**1.5).round
        circle(bmp, cx, cy, rr, col(*rgb, a))
      end
    end

    def build
      @shared = []
      build_stars
      @exit_glow = sprite(Bitmap.new(80, 40), 5, 6, H - 46)
      glow(@exit_glow.bitmap, 40, 20, 19, [80, 255, 120], 200)
      @galaxy = sprite(galaxy_bitmap, 6, 360, 150, true)
      @moon = sprite(moon_bitmap, 20, MOON_C[0], H + 60, true)
      gas_bmp = Bitmap.new(44, 44)
      glow(gas_bmp, 22, 22, 21, [190, 220, 70], 150)
      @shared << gas_bmp
      @gas = Array.new(6) { sprite(gas_bmp, 21, 0, 0, true) }
      @north = sprite(north_bitmap, 22, 0, 0, true)
      @mars = sprite(mars_bitmap, 20, -60, 150, true)
      @sat = sprite(satellite_bitmap, 24, -40, SAT_Y[0], true)
      @sat2 = sprite(satellite_bitmap, 24, W + 40, SAT_Y[1], true)
      @blink = sprite(dot_bitmap(3, [255, 60, 60]), 25, 0, 0, true)
      @laser = sprite(dot_bitmap(4, [255, 30, 30]), 26, 256, H, true)
      missile = Bitmap.new(14, 3)
      missile.fill_rect(0, 1, 10, 1, col(255, 170, 60, 180))
      missile.fill_rect(10, 0, 4, 3, col(255, 240, 200))
      @shared << missile
      @missiles = Array.new(6) { sprite(missile, 25, 0, 0, true) }
      @red = sprite(horizon_bitmap([200, 30, 20]), 10, 0, H - 140)
      @blue = sprite(horizon_bitmap([90, 150, 230]), 11, 0, H - 140)
      build_meteors
      build_countdown
    end

    def build_stars
      per = R::STARS / STAR_SPEEDS.length
      @planes = STAR_SPEEDS.each_with_index.map do |_, li|
        bmp = Bitmap.new(W, H)
        per.times do
          x, y = @rng.rand(W), @rng.rand(H - 20)
          b = 120 + @rng.rand(80) + li * 25
          bmp.fill_rect(x, y, 1 + (li == 2 ? 1 : 0), 1 + (li == 2 ? 1 : 0), col(b, b, [b + 20, 255].min))
        end
        pl = Plane.new(@vp)
        pl.bitmap = bmp
        pl.z = 1 + li
        pl.opacity = 0
        @all << pl
        pl
      end
      tw = Bitmap.new(5, 5)
      tw.fill_rect(2, 0, 1, 5, col(255, 250, 220, 200))
      tw.fill_rect(0, 2, 5, 1, col(255, 250, 220, 200))
      tw.fill_rect(1, 1, 3, 3, col(255, 255, 240))
      @shared << tw
      @twinkles = Array.new(R::TWINKLES) { sprite(tw, 4, @rng.rand(W - 5), @rng.rand(H - 60)) }
    end

    def galaxy_bitmap
      bmp = Bitmap.new(240, 240)
      400.times do |i|
        arm = i % 2
        f = @rng.rand
        ang = f * 3.6 * Math::PI + arm * Math::PI
        rad = 8 + f * 105 + @rng.rand(10)
        x = (120 + Math.cos(ang) * rad).round
        y = (120 + Math.sin(ang) * rad * 0.55).round
        a = (220 * (1 - f * 0.7)).round
        bmp.fill_rect(x, y, 1 + @rng.rand(2), 1, col(210, 190, 255, a))
      end
      glow(bmp, 120, 120, 16, [255, 240, 220], 160)
      bmp
    end

    def moon_bitmap
      bmp = Bitmap.new(100, 100)
      48.step(1, -1) do |r|
        shade = 150 + (105 * (1 - r / 48.0)).round
        circle(bmp, 46, 46, r, col(shade, shade, shade - 12))
      end
      [[30, 34, 7], [58, 26, 5], [62, 58, 9], [36, 64, 6], [50, 44, 4], [24, 50, 3]].each do |x, y, r|
        circle(bmp, x, y, r, col(150, 150, 140))
        circle(bmp, x - 1, y - 1, [r - 2, 1].max, col(178, 178, 168))
      end
      bmp
    end

    def north_bitmap
      bmp = Bitmap.new(48, 48)
      glow(bmp, 24, 24, 22, [200, 220, 255], 120)
      (1..20).each do |d|
        a = (255 * (1 - d / 21.0)).round
        w = d < 6 ? 3 : 1
        [[24 - w / 2, 24 - d], [24 - w / 2, 24 + d]].each { |x, y| bmp.fill_rect(x, y, w, 1, col(255, 255, 255, a)) }
        [[24 - d, 24 - w / 2], [24 + d, 24 - w / 2]].each { |x, y| bmp.fill_rect(x, y, 1, w, col(255, 255, 255, a)) }
      end
      circle(bmp, 24, 24, 3, col(255, 255, 255))
      bmp
    end

    def mars_bitmap
      bmp = Bitmap.new(84, 84)
      glow(bmp, 42, 42, 41, [255, 90, 40], 60)
      36.step(1, -1) do |r|
        f = 1 - r / 36.0
        circle(bmp, 42, 42, r, col(170 + (70 * f).round, 60 + (40 * f).round, 30))
      end
      circle(bmp, 30, 8, 6, col(185, 75, 35))   # Olympus Mons on the rim
      circle(bmp, 52, 50, 6, col(150, 50, 25))
      bmp
    end

    def satellite_bitmap
      bmp = Bitmap.new(44, 18)
      bmp.fill_rect(0, 5, 14, 8, col(60, 90, 170))
      bmp.fill_rect(30, 5, 14, 8, col(60, 90, 170))
      [3, 7, 10].each { |x| bmp.fill_rect(x, 5, 1, 8, col(30, 50, 110)) }
      [33, 37, 40].each { |x| bmp.fill_rect(x, 5, 1, 8, col(30, 50, 110)) }
      bmp.fill_rect(14, 8, 16, 2, col(150, 150, 160))
      bmp.fill_rect(17, 3, 10, 12, col(210, 210, 220))
      bmp.fill_rect(19, 5, 6, 3, col(120, 130, 150))
      @shared << bmp
      bmp
    end

    def dot_bitmap(r, rgb)
      bmp = Bitmap.new(r * 4 + 2, r * 4 + 2)
      glow(bmp, r * 2 + 1, r * 2 + 1, r * 2, rgb, 120)
      circle(bmp, r * 2 + 1, r * 2 + 1, r / 2 + 1, col(*rgb))
      bmp
    end

    def horizon_bitmap(rgb)
      bmp = Bitmap.new(W, 140)
      140.times { |y| bmp.fill_rect(0, y, W, 1, col(*rgb, (210 * (y / 139.0)**1.6).round)) }
      bmp
    end

    def build_meteors
      streak = Bitmap.new(46, 3)
      46.times { |x| streak.fill_rect(x, 1, 1, 1, col(255, 245, 220, (255 * x / 45.0).round)) }
      streak.fill_rect(42, 0, 4, 3, col(255, 255, 255))
      @shared << streak
      @meteor_starts = Array.new(R::METEORS) { [180 + @rng.rand(W), -10 + @rng.rand(150)] }
      @meteors = Array.new(R::METEORS) do
        m = sprite(streak, 15, 0, 0, true)
        m.angle = 150   # tail up-right, head down-left
        m
      end
    end

    def build_countdown
      @digits = {}
      (1..R::COUNTDOWN).each do |n|
        bmp = Bitmap.new(140, 90)
        pbSetSystemFont(bmp) if defined?(pbSetSystemFont)
        bmp.font.size = 64
        bmp.font.color = col(40, 10, 10)
        bmp.draw_text(3, 3, 140, 90, n.to_s, 1)
        bmp.font.color = col(255, 236, 200)
        bmp.draw_text(0, 0, 140, 90, n.to_s, 1)
        @digits[n] = bmp
        @shared << bmp
      end
      @digit = sprite(@digits[R::COUNTDOWN], 60, W / 2, H / 2 - 20, true)
      flash = Bitmap.new(W, H)
      flash.fill_rect(0, 0, W, H, col(255, 255, 255))
      @flash = sprite(flash, 80)
      spark = Bitmap.new(7, 7)
      glow(spark, 3, 3, 3, [255, 220, 120], 255)
      spark.fill_rect(3, 0, 1, 7, col(255, 250, 200))
      spark.fill_rect(0, 3, 7, 1, col(255, 250, 200))
      @shared << spark
      @sparks = Array.new(24) { sprite(spark, 70, 0, 0, true) }
    end
  end
end
