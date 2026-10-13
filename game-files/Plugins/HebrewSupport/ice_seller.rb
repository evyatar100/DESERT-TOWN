#===============================================================================
# Popcorn / Ice Seller NPC Dialogue & Choice Handler (Map 091 - Ice Out)
#===============================================================================

module IceSellerRules
  BILLS_REQUIRED = 5

  # Pure decision for one menu pick. The caller still shows messages and edits the bag.
  # Returns :purchase, :not_enough, :line, :no_money, :deserttown, or :exit.
  def self.decide(choice, bill_count)
    case choice
    when 0
      bill_count.to_i >= BILLS_REQUIRED ? :purchase : :not_enough
    when 1
      :line
    when 2
      :no_money
    when 3
      :deserttown
    else
      :exit
    end
  end
end

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
    bills = $bag.quantity(:TWENTYSHECKELBILL)

    case IceSellerRules.decide(choice, bills)
    when :purchase
      # תשלום 100 שקלים: 5 "20 SHECKEL BILLS"
      $bag.remove(:TWENTYSHECKELBILL, IceSellerRules::BILLS_REQUIRED)
      pbReceiveItem(:ICEBAG)
      pbMessage(_INTL("POPCORN_RESPONSE_THANKS"))
      break
    when :not_enough
      pbMessage(_INTL("POPCORN_RESPONSE_NOT_ENOUGH"))
    when :line
      # למה יש כאן תור?
      pbMessage(_INTL("POPCORN_RESPONSE_LINE"))
    when :no_money
      # איך לי 100 שקלים
      pbMessage(_INTL("POPCORN_RESPONSE_NO_MONEY"))
    when :deserttown
      # כסף בדזרטאון?
      pbMessage(_INTL("POPCORN_RESPONSE_DESERTTOWN"))
    else
      # יציאה (or Cancel)
      break
    end
  end
end

alias pbPopcornEvent pbIceSeller
