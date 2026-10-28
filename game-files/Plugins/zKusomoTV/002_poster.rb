# Poster shown for exactly 10 s after each Kusomo TV video, with a "game resumes in N" countdown
# on the right side bar (the poster itself is the centre 307 px, so its text stays uncovered).
module KusomoTV
  POSTER = "Graphics/Pictures/KusomoTV/poster"
  POSTER_SECONDS = 10
  NAVY = [18, 20, 31]
  PLATE = [412, 296, 98, 80]   # x, y, w, h inside the right bar, bottom corner

  # Blocks for POSTER_SECONDS with no skip; every button press is swallowed. No-op if the PNG is missing.
  def self.show_poster
    path = pbResolveBitmap(POSTER)
    trace("poster: resolved #{path.inspect}")
    return false if !path
    vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
    vp.z = 99999
    sprites = []
    begin
      back = Sprite.new(vp)
      back.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      back.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(*NAVY))
      sprites << back
      pic = Sprite.new(vp)
      pic.bitmap = Bitmap.new(path)
      sprites << pic
      trace("poster: bitmap #{pic.bitmap.width}x#{pic.bitmap.height}")
      ui = Sprite.new(vp)
      ui.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      ui.z = 1
      sprites << ui
      start = System.uptime
      shown = nil
      frames = 0
      loop do
        left = POSTER_SECONDS - (System.uptime - start)
        break if left <= 0
        n = left.ceil.clamp(1, POSTER_SECONDS)
        if n != shown
          shown = n
          draw_countdown(ui.bitmap, n)
          trace("poster: countdown #{n} frame #{frames}")
        end
        Graphics.update
        Input.update
        frames += 1
      end
      trace("poster: loop done after #{frames} frames")
    ensure
      sprites.each { |s| s.bitmap&.dispose; s.dispose }
      vp.dispose
      trace("poster: disposed")
    end
    Input.update
    return true
  end

  def self.draw_countdown(bmp, n)
    bmp.clear
    x, y, w, h = PLATE
    bmp.fill_rect(x, y, w, h, Color.new(0, 0, 0, 200))
    bmp.fill_rect(x, y, w, 2, Color.new(255, 214, 64))
    words = _INTL("KUSOMO_TV_RESUME", n).split(" ")
    cut = [words.length - 2, 1].max
    lines = [words[0, cut].join(" "), words[cut..].join(" ")]
    bmp.font.size = 16
    pbDrawShadowText(bmp, x, y + 8, w, 24, lines[0], Color.new(248, 240, 224), Color.new(24, 18, 28), 1)
    bmp.font.size = 30
    pbDrawShadowText(bmp, x, y + 34, w, 40, lines[1], Color.new(255, 214, 64), Color.new(24, 18, 28), 1)
  end
end
