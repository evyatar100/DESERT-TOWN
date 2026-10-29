#===============================================================================
# DesertScreens (TG57) - Continue panel and Save window: no Badges or Pokedex rows,
# Hebrew area name, Desert Town text colours. Row builders are pure (unit-tested).
#===============================================================================

module DesertScreens
  def self.play_time_text(totalsec)
    hour = totalsec.to_i / 3600
    min = totalsec.to_i / 60 % 60
    return _INTL("{1}h {2}m", hour, min) if hour > 0
    return _INTL("{1}m", min)
  end

  # [text, x, y, align, role] for the Continue panel; role picks the colour in the glue below.
  def self.continue_rows(title, name, area, totalsec)
    return [
      [title, 32, 16, :left, :text],
      [name, 112, 70, :left, :name],
      [area, 386, 16, :right, :text],
      [_INTL("Time:"), 32, 182, :left, :text],
      [play_time_text(totalsec), 206, 182, :right, :text]
    ]
  end

  # Save window text: area, then Player and Time only (loc_tag/text_tag are the colour tags).
  def self.save_text(area, name, totalsec, loc_tag, text_tag)
    text = loc_tag + "<ac>" + area + "</ac></c3>"
    text += _INTL("Player") + "<r>" + text_tag + name + "</c3><br>"
    text += _INTL("Time") + "<r>" + text_tag + play_time_text(totalsec) + "</c3>"
    return text
  end

  module LoadPanelRows
    def refresh
      return if @refreshing || disposed?
      @refreshing = true
      if !self.bitmap || self.bitmap.disposed?
        self.bitmap = Bitmap.new(@bgbitmap.width, 222)
        pbSetSystemFont(self.bitmap)
      end
      if @refreshBitmap
        @refreshBitmap = false
        self.bitmap&.clear
        if @isContinue
          self.bitmap.blt(0, 0, @bgbitmap.bitmap, Rect.new(0, (@selected) ? 222 : 0, @bgbitmap.width, 222))
        else
          self.bitmap.blt(0, 0, @bgbitmap.bitmap, Rect.new(0, 444 + ((@selected) ? 46 : 0), @bgbitmap.width, 46))
        end
        pbDrawTextPositions(self.bitmap, text_positions)
      end
      @refreshing = false
    end

    def text_positions
      cream = Color.new(255, 248, 236)
      gold = Color.new(232, 184, 96)
      ink = Color.new(42, 22, 8)
      return [[@title, 32, 14, :left, cream, ink]] if !@isContinue
      area = DesertScreens.area_name(@mapid) || pbGetMapNameFromId(@mapid).gsub(/\PN/, @trainer.name)
      rows = DesertScreens.continue_rows(@title, @trainer.name, area, @totalsec)
      return rows.map { |t, x, y, align, role| [t, x, y, align, (role == :name) ? gold : cream, ink] }
    end
  end

  module SaveSceneRows
    def pbStartScreen
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99999
      @sprites = {}
      scene = PokemonSave_Scene
      text_tag = shadowc3tag(scene::MALE_TEXT_BASE, scene::MALE_TEXT_SHADOW)
      text_tag = shadowc3tag(scene::FEMALE_TEXT_BASE, scene::FEMALE_TEXT_SHADOW) if $player.female?
      area = DesertScreens.area_name($game_map.map_id) || $game_map.name
      loctext = DesertScreens.save_text(area, $player.name, $stats.play_time.to_i,
                                        shadowc3tag(scene::LOCATION_TEXT_BASE, scene::LOCATION_TEXT_SHADOW), text_tag)
      @sprites["locwindow"] = Window_AdvancedTextPokemon.new(loctext)
      @sprites["locwindow"].viewport = @viewport
      @sprites["locwindow"].x = 0
      @sprites["locwindow"].y = 0
      @sprites["locwindow"].width = 228 if @sprites["locwindow"].width < 228
      @sprites["locwindow"].visible = true
    end
  end
end

class PokemonLoadPanel
  prepend DesertScreens::LoadPanelRows
end

class PokemonSave_Scene
  prepend DesertScreens::SaveSceneRows
end
