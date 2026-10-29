#===============================================================================
# LilyHappy - the payoff on the map (spec D9): the report beats under Lily's portrait,
# grumpy -> curious -> giggle -> beam, the heart balloon and the jingle, then :done.
#===============================================================================

module LilyHappy
  # Lily's face over the map, under the message window. No lily_faces.png = nothing drawn.
  module Portrait
    Z = 99_998
    MSG_H = 96                     # the 2-line message window at the bottom

    def self.open
      close
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = Z
      @sheet = Art.faces
      @sprite = Sprite.new(@viewport)
      @sprite.bitmap = @sheet
      @sprite.x = 8
      @sprite.y = Graphics.height - MSG_H - Art::FACE - 8
      @sprite.visible = false
    end

    def self.viewport = @viewport
    def self.face = @face
    def self.visible? = !!(@sprite && @sheet && @sprite.visible)

    def self.show(face)
      @face = face
      return unless @sprite && @sheet
      @sprite.src_rect = Rect.new(Art::FACES.index(face) * Art::FACE, 0, Art::FACE, Art::FACE)
      @sprite.visible = true
    end

    def self.balloon(event)
      return unless @viewport && event
      @balloon = Sprite.new(@viewport)
      @balloon.bitmap = Art.heart_balloon
      @balloon.x = event.screen_x - 10
      @balloon.y = event.screen_y - 70
    end

    def self.drop_balloon
      return unless @balloon
      @balloon.bitmap.dispose unless @balloon.bitmap.disposed?
      @balloon.dispose unless @balloon.disposed?
      @balloon = nil
    end

    def self.close
      drop_balloon
      @sprite.dispose if @sprite && !@sprite.disposed?
      @sheet.dispose if @sheet && !@sheet.disposed?
      @viewport.dispose if @viewport && !@viewport.disposed?
      @sprite = @sheet = @viewport = nil
    end
  end

  JINGLE = "Slots big win"

  # The Lily event the player is facing on this map (nearest by name).
  def self.lily_event
    return nil unless $game_map && $game_player
    evs = $game_map.events.values.select { |e| e.name == R::LILY_CHARSET }
    evs.min_by { |e| (e.x - $game_player.x).abs + (e.y - $game_player.y).abs }
  end

  # The single :wheeled -> :done step; an interrupted payoff replays in full next talk.
  def self.payoff(st)
    return false unless st[:stage] == :wheeled
    Portrait.open
    begin
      report(st)
      Portrait.show(:beam)
      say("LILY_PAYOFF_1")
      Portrait.balloon(lily_event)
      pbMEPlay(JINGLE) if defined?(pbMEPlay)
      say("LILY_PAYOFF_2")
      Portrait.drop_balloon
      say("LILY_PAYOFF_3", nil)
      R.finish!(st)
      autosave
    ensure
      Portrait.close
    end
    true
  end

  def self.report(st)
    Portrait.show(:grumpy)
    say("LILY_REPORT_OPEN", nil)
    st[:heard].each_with_index do |enc, i|
      say("LILY_REPORT_#{enc.to_s.upcase}", nil)
      Portrait.show(i.zero? ? :curious : :giggle)
      say("LILY_REACT_#{i + 1}")
    end
    say("LILY_REPORT_WHEEL", nil, st[:best] || 0, st[:laps])
    Portrait.show(:giggle)
    say((st[:best] || 0) >= R::CAP ? "LILY_REACT_WHEEL" : "LILY_REACT_WHEEL_LOW")
  end
end
