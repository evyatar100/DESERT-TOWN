#===============================================================================
# Bags - using the Bag of Bags and opening a Surprise Bag (bag screen or Ready menu).
# Both are key items, so the engine never removes them; BagsRules does.
#===============================================================================

module Bags
  # Bag of Bags: a Desert Bag when none is held, otherwise USE_FULL.
  def self.use_bag_of_bags
    return false if !$bag
    if BagsRules.bag_of_bags_use!($bag) == :filled
      @bob_turn = ((@bob_turn || 0) % 3) + 1
      say("BAGS_BAGOFBAGS_USE_#{@bob_turn}")
    else
      say("BAGS_BAGOFBAGS_USE_FULL")
    end
    true
  end

  # Surprise Bag: warn while Inbar still needs them, confirm, remove one, then roll.
  def self.open_surprise_bag
    return false if !$bag
    qty = $bag.quantity(:SURPRISEBAG)
    return false if qty <= 0
    say("BAGS_SURPRISE_WARN_INBAR") if BagsRules.warn_inbar?(state, qty)
    DesertTalk.name_key = nil if defined?(DesertTalk)
    return false unless pbConfirmMessage(_INTL("BAGS_SURPRISE_CONFIRM"))
    outcome = BagsRules.open_surprise!(state, $bag, rng)
    return false unless outcome
    say("BAGS_SURPRISE_#{outcome.to_s.upcase}")
    true
  end
end

ItemHandlers::UseFromBag.add(:BAGOFBAGS, proc { |_item|
  next Bags.use_bag_of_bags ? 1 : 0
})

ItemHandlers::UseInField.add(:BAGOFBAGS, proc { |_item|
  next Bags.use_bag_of_bags
})

ItemHandlers::UseFromBag.add(:SURPRISEBAG, proc { |_item|
  next Bags.open_surprise_bag ? 1 : 0
})

ItemHandlers::UseInField.add(:SURPRISEBAG, proc { |_item|
  next Bags.open_surprise_bag
})
