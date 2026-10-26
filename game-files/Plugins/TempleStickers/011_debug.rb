#===============================================================================
# TempleStickers - debug hook for laptop testing (F9 menu, debug playtests only).
# Debug > Desert Town... > Temple sticker board: collects all 12 stickers and
# opens a board.
#===============================================================================

module TempleStickers
  # Marks every sticker as collected; returns how many were new.
  def self.debug_give_all
    r = run
    STICKERS.keys.count { |s| collect(r, s) }
  end
end

MenuHandlers.add(:debug_menu, :dt_temple_board, {
  "name"        => "Temple sticker board",
  "parent"      => :desert_town_menu,
  "description" => "Collect all 12 temple stickers and open a board.",
  "always_show" => true,
  "effect"      => proc {
    if !$player
      pbMessage("No player loaded yet.")
      next false
    end
    TempleStickers.debug_give_all
    boards = TempleStickers::BOARDS.keys
    choice = pbShowCommands(nil, boards + ["Cancel"], boards.length + 1)
    pbTempleBoard(boards[choice]) if choice < boards.length
    next false
  }
})
