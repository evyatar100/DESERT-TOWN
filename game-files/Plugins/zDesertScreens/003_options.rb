#===============================================================================
# DesertScreens (TG57) - Options: the rows that only mean something for Pokemon
# battles, boxes and frame choice are removed (ids in 000_rules.rb).
#===============================================================================

module DesertScreens
  def self.hide_option_rows(handlers)
    HIDDEN_OPTION_IDS.each { |id| handlers.remove(:options_menu, id) }
    return HIDDEN_OPTION_IDS
  end
end

DesertScreens.hide_option_rows(MenuHandlers)
