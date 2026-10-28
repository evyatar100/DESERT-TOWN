#===============================================================================
# DesertScreens (TG57) - Desert Town title and Continue music.
# Sets the title BGM name in memory just before the title plays; System.rxdata is
# untouched, and the Continue screen keeps whatever the title started.
#===============================================================================

module DesertScreens
  def self.apply_title_bgm(system)
    bgm = system && system.title_bgm
    return false if !bgm || !bgm.respond_to?(:name=)
    return false if defined?(pbResolveAudio) && !pbResolveAudio("Audio/BGM/" + TITLE_BGM)
    bgm.name = TITLE_BGM
    return true
  end

  module TitleMusic
    def open_title_screen(scene, *args)
      DesertScreens.apply_title_bgm($data_system)
      super
    end
  end
end

class IntroEventScene
  prepend DesertScreens::TitleMusic
end
