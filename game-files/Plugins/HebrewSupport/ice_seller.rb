#===============================================================================
# Popcorn / Ice Seller NPC Dialogue & Choice Handler (Map 091 - Ice Out)
#===============================================================================

def pbIceSeller
  # 1. Opening dialogue
  pbMessage(_INTL("POPCORN_INTRO"))

  # 2. Main interactive choices loop
  loop do
    commands = [
      _INTL("POPCORN_CHOICE_1"), # תשלום 100 שקלים
      _INTL("POPCORN_CHOICE_2"), # למה יש כאן תור?
      _INTL("POPCORN_CHOICE_3"), # איך לי 100 שקלים
      _INTL("POPCORN_CHOICE_4"), # כסף בדזרטאון?
      _INTL("POPCORN_CHOICE_5")  # יציאה
    ]

    # Show commands. Cancel button (B/Esc) selects Choice 5 (cmdIfCancel = 5)
    choice = pbShowCommands(nil, commands, 5)

    case choice
    when 0
      # 1. תשלום 100 שקלים: Check if player has 5 "20 SHECKEL BILLS"
      bills = $bag.quantity(:TWENTYSHECKELBILL)
      if bills >= 5
        $bag.remove(:TWENTYSHECKELBILL, 5)
        pbReceiveItem(:ICEBAG)
        pbMessage(_INTL("POPCORN_RESPONSE_THANKS"))
        break
      else
        pbMessage(_INTL("POPCORN_RESPONSE_NOT_ENOUGH"))
      end
    when 1
      # 2. למה יש כאן תור?
      pbMessage(_INTL("POPCORN_RESPONSE_LINE"))
    when 2
      # 3. איך לי 100 שקלים
      pbMessage(_INTL("POPCORN_RESPONSE_NO_MONEY"))
    when 3
      # 4. כסף בדזרטאון?
      pbMessage(_INTL("POPCORN_RESPONSE_DESERTTOWN"))
    else
      # 5. יציאה (or Cancel)
      break
    end
  end
end

alias pbPopcornEvent pbIceSeller
