#===============================================================================
# Bags - Inbar (map 95), cowboy Shirpaz and Pixel hook in after their own line by
# aliasing pbDesertTalk, so their map events stay untouched. Also the unicorn page script.
#===============================================================================

module Bags
  INBAR = "c414cf08"
  COWBOY = "670f79e3"
  PIXEL = "d5383627"

  # [key, speaker] in show order. Speakers follow the copy doc.
  ARRIVAL = [
    ["BAGS_UNICORN_ARRIVE_1", :duo], ["BAGS_UNICORN_ARRIVE_2", :shirpaz], ["BAGS_UNICORN_ARRIVE_3", :esther],
    ["BAGS_UNICORN_STAR_1", :shirpaz], ["BAGS_UNICORN_STAR_2", :esther],
    ["BAGS_UNICORN_ACCEPT_1", :shirpaz], ["BAGS_UNICORN_ACCEPT_2", :esther]
  ].freeze
  PRESONG = ["BAGS_UNICORN_PRESONG", :duo].freeze
  AFTER_SONG = [
    ["BAGS_UNICORN_AFTER_1", :shirpaz], ["BAGS_UNICORN_AFTER_2", :esther],
    ["BAGS_UNICORN_AFTER_3", :shirpaz], ["BAGS_UNICORN_AFTER_4", :esther]
  ].freeze
  # Pay item => [choice key, Pixel's thank-you key], one per BagsRules::PAY_ITEMS.
  PAY_KEYS = {
    DESERTBAG:         %w[BAGS_PIXEL_CHOICE_DESERT BAGS_PIXEL_PAID_DESERT],
    ICEBAG:            %w[BAGS_PIXEL_CHOICE_ICE BAGS_PIXEL_PAID_ICE]
  }.freeze
  MEOW_SE = "Cries/MEOWTH"

  def self.after_talk(character_id)
    case character_id
    when INBAR then inbar_talk if $game_map && $game_map.map_id == INBAR_MAP
    when COWBOY then cowboy_talk
    when PIXEL then pixel_talk
    end
  end

  def self.lines(list)
    list.each { |key, speaker| say(key, speaker) }
  end

  def self.inbar_talk
    st = state
    qty = inbar_count   # every bag Inbar accepts right now (Surprise Bags, and the Music Bag after its delivery)
    case BagsRules.inbar_decide(st, qty)
    when :intro
      BagsRules.ask!(st)
      lines([["BAGS_INBAR_ASK_1", :inbar], ["BAGS_INBAR_ASK_2", :inbar], ["BAGS_INBAR_ASK_3", :inbar]])
    when :short
      say("BAGS_INBAR_MUSICBAG_NOT_YET", :inbar) if BagsRules.music_not_yet?(st, $bag, gates)
      say("BAGS_INBAR_NOTENOUGH", :inbar, qty)
    when :offer then inbar_offer
    when :party then lines([["BAGS_INBAR_PARTY_1", :inbar], ["BAGS_INBAR_PARTY_2", :inbar]])
    end
  end

  def self.inbar_offer
    pick = choose("BAGS_INBAR_GIVE_ASK", :inbar, %w[BAGS_INBAR_CHOICE_GIVE BAGS_INBAR_CHOICE_NOTYET])
    return say("BAGS_INBAR_NOTYET", :inbar) if pick != 0
    return unless hand_over!
    place_offscreen   # same frame as S106: they never pop in at their spots
    say("BAGS_UNICORN_GIVEN")
    say("BAGS_INBAR_SUMMON", :inbar)
    walk_in
    lines(ARRIVAL)
    after_song
    say(*PRESONG)
    Song.start(duo: true)
  end

  # AFTER lines, then the one Surprise Bag back. Runs before the song (rev 2), and is
  # the recovery path for a rev-1 save that stopped between the hand-over and the payoff.
  def self.after_song
    lines(AFTER_SONG)
    DesertTalk.name_key = nil if defined?(DesertTalk)
    pbReceiveItem(:SURPRISEBAG) if BagsRules.payoff!(state)
  end

  # Name clash after the party, then the arm-wrestling challenge (zArmWrestle; dec:tg-29 (founder: wins give bags), dec:tg-30 (design)).
  def self.cowboy_talk
    say("BAGS_SHIRPAZ_COWBOY_CLASH", :cowboy) if state[:inbar] == :done
    ArmWrestle.offer(busy: Song.active?) if defined?(ArmWrestle)
  end

  def self.pixel_talk
    say("BAGS_PIXEL_OFFER_1", :pixel)
    say("BAGS_PIXEL_OFFER_2", :pixel) unless @pixel_offered
    @pixel_offered = true
    items = $bag ? BagsRules.payable($bag) : []
    return say("BAGS_PIXEL_NOTHING", :pixel) if items.empty?
    item = pixel_pick(items)
    return say("BAGS_PIXEL_NEVERMIND", :pixel) if !item || !BagsRules.trade!($bag, item)
    say(PAY_KEYS[item][1], :pixel)
    pbSEPlay(MEOW_SE) if FileTest.audio_exist?("Audio/SE/#{MEOW_SE}")
    say("BAGS_PIXEL_MEOW")
    say("BAGS_PIXEL_REVEAL", :pixel)
  end

  # One payable item: a deal / never mind question. Several: the item menu. Nil = never mind.
  def self.pixel_pick(items)
    if items.length == 1
      deal = choose("BAGS_PIXEL_CHOOSE_ONE", :pixel, %w[BAGS_PIXEL_CHOICE_DEAL BAGS_PIXEL_CHOICE_NEVERMIND])
      return deal == 0 ? items[0] : nil
    end
    keys = items.map { |i| PAY_KEYS[i][0] } + ["BAGS_PIXEL_CHOICE_NEVERMIND"]
    items[choose("BAGS_PIXEL_CHOOSE", :pixel, keys)]
  end
end

alias bags_pbDesertTalk pbDesertTalk unless defined?(bags_pbDesertTalk)
def pbDesertTalk(character_id, line_key = nil)
  ret = bags_pbDesertTalk(character_id, line_key)
  Bags.after_talk(character_id)
  ret
end

# Unicorn page script (only while they stand by Inbar): crash-recovery payoff first,
# otherwise the encore, which starts the song with them following, then they leave.
def pbBagsUnicorn(which = :esther)
  st = Bags.state
  return false unless st[:inbar] == :done
  return Bags.after_song if BagsRules.payoff_pending?(st)
  speaker = Bags::UNICORNS.include?(which) ? which : :esther
  pick = Bags.choose("BAGS_UNICORN_ENCORE_ASK", speaker, %w[BAGS_UNICORN_CHOICE_ENCORE BAGS_UNICORN_CHOICE_NO])
  if pick == 0
    Bags.say("BAGS_UNICORN_ENCORE_YES", :esther)
    Bags::Song.start(duo: true)
  else
    Bags.say("BAGS_UNICORN_ENCORE_NO", :esther)
  end
  true
end
