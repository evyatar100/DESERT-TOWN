#===============================================================================
# TempleStickers - TEMPORARY debug hook (until the phase 2 signs exist).
# Debug > Desert Town... > Temple sticker board: collects the whole hand and
# opens a board. Remove once signs give stickers.
#===============================================================================

module TempleStickers
  # Marks every hand sticker as collected; returns how many were new.
  def self.debug_give_hand
    r = run
    r[:hand].count { |s| collect(r, s) }
  end
end

MenuHandlers.add(:debug_menu, :dt_temple_board, {
  "name"        => "Temple sticker board",
  "parent"      => :desert_town_menu,
  "description" => "Collect this run's 4 temple stickers and open a board (temporary, before signs).",
  "always_show" => true,
  "effect"      => proc {
    if !$player
      pbMessage("No player loaded yet.")
      next false
    end
    TempleStickers.debug_give_hand
    boards = TempleStickers::BOARDS.keys
    choice = pbShowCommands(nil, boards + ["Cancel"], boards.length + 1)
    pbTempleBoard(boards[choice]) if choice < boards.length
    next false
  }
})
