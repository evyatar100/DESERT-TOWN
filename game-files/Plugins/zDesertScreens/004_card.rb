#===============================================================================
# DesertScreens (TG57) - Trainer Card: name, play time, start date and game depth.
# No ID, money, Pokedex or badges. Row builder is pure (unit-tested).
#===============================================================================

module DesertScreens
  # Day.month.year, so no English month name reaches a Hebrew screen.
  def self.started_text(time)
    return sprintf("%d.%d.%d", time.day, time.mon, time.year)
  end

  # [text, x, y, align] on the four sand bars drawn by assets-factory/desert_screens/card.py.
  def self.card_rows(name, time_text, started, depth)
    return [
      [_INTL("Name"), 34, 70, :left], [name, 302, 70, :right],
      [_INTL("Time"), 34, 118, :left], [time_text, 302, 118, :right],
      [_INTL("Started"), 34, 166, :left], [started, 302, 166, :right],
      [_INTL("Depth"), 34, 214, :left], [depth.to_s, 302, 214, :right]
    ]
  end

  module TrainerCardRows
    def pbDrawTrainerCardFront
      overlay = @sprites["overlay"].bitmap
      overlay.clear
      $PokemonGlobal.startTime = Time.now if !$PokemonGlobal.startTime
      rows = DesertScreens.card_rows($player.name, DesertScreens.play_time_text($stats.play_time.to_i),
                                     DesertScreens.started_text($PokemonGlobal.startTime), DesertTownArcade.depth)
      ink = Color.new(42, 22, 8)
      shade = Color.new(214, 168, 96)
      pbDrawTextPositions(overlay, rows.map { |t, x, y, align| [t, x, y, align, ink, shade] })
    end
  end
end

class PokemonTrainerCard_Scene
  prepend DesertScreens::TrainerCardRows
end
