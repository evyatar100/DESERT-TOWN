#===============================================================================
# TownSloth (עצלן הטאון) — Square Road Temple character-select offer
#===============================================================================
# Called from Map096 event TownSloth. Speaker must already be set with
# pbDesertSpeaker("14538600") so the name plate stays for every message.
#===============================================================================

def pbTownSloth
  choice = pbMessage(
    _INTL("MSG_14538600_SQUARE_INTRO"),
    [_INTL("MSG_14538600_SQUARE_YES"), _INTL("MSG_14538600_SQUARE_NO")],
    2
  )
  if choice == 0
    if pbDesertCharSelect
      pbMessage(_INTL("MSG_14538600_SQUARE_REFRESHED"))
    end
  elsif choice == 1
    pbMessage(_INTL("MSG_14538600_SQUARE_NEWGAME"))
  end
end
