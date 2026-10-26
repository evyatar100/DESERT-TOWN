#===============================================================================
# Bags - Toga's "question about a bag" branch (Map098 ev10, conditional script).
# True ends the event (gift or desert hand-over close on Toga's own last line);
# false returns to his topic menu.
#===============================================================================

module Bags
  TOGA_KEY = "MSG_7A2A022C_BAG"

  def self.toga_line(suffix)
    say("#{TOGA_KEY}_#{suffix}", :toga)
  end

  def self.toga_again
    @toga_again = ((@toga_again || 0) % 3) + 1
    toga_line("AGAIN_#{@toga_again}")
    false
  end

  def self.toga_gift
    %w[1 2 3].each { |n| toga_line(n) }
    pick = choose("#{TOGA_KEY}_Q", :toga, %w[CHOICE_7A2A022C_BAG_A CHOICE_7A2A022C_BAG_B])
    toga_line(pick == 1 ? "4B" : "4A")
    %w[5 6 GIFT GIFT_2].each { |s| toga_line(s) }
    if BagsRules.toga_gift!(state)
      DesertTalk.name_key = nil if defined?(DesertTalk)
      pbReceiveItem(:BAGOFBAGS)
    end
    toga_line("GIFT_3")
    true
  end

  def self.toga_desert
    pick = choose("MSG_7A2A022C_DESERTBAG_1", :toga, %w[CHOICE_7A2A022C_DESERTBAG_GIVE CHOICE_7A2A022C_DESERTBAG_KEEP])
    if pick != 0 || !BagsRules.toga_desert!(state, $bag)
      say("MSG_7A2A022C_DESERTBAG_KEEP", :toga)
      return false
    end
    %w[2 3 4].each { |n| say("MSG_7A2A022C_DESERTBAG_#{n}", :toga) }
    true
  end

  def self.toga
    holds_desert = $bag && $bag.quantity(:DESERTBAG) > 0
    case BagsRules.toga_branch(state, holds_desert)
    when :gift then toga_gift
    when :desert_offer then toga_desert
    when :desert_seen
      say("MSG_7A2A022C_DESERTBAG_SEEN", :toga)
      toga_again
    else toga_again
    end
  end
end

# Map098 ev10 BAG branch: `111 [12, "pbBagsToga"]` -> exit on true, back to TOGA_CHOOSE on false.
def pbBagsToga
  Bags.toga
end
