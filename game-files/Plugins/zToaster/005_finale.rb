#===============================================================================
# Toaster - Eyal's finale at Kusomo: what to unplug, the pop, the fixed line,
# the ceremony and the framed crumb. deliver! -> pop -> END line -> ceremony -> crumb!.
#===============================================================================

module Toaster
  FINALE = %w[TOAST_EYAL_FINALE_1 TOAST_EYAL_FINALE_2 TOAST_EYAL_FINALE_3].freeze
  PLUG_CHOICES = %w[TOAST_PLUG_CHOICE_AC TOAST_PLUG_CHOICE_JAR TOAST_PLUG_CHOICE_NOTYET].freeze
  # [key, speaker] per plug; Oren howls offscreen.
  PLUG_LINES = {
    ac: [["TOAST_PLUG_AC_1", :eyal], ["TOAST_PLUG_AC_2", :oren]],
    jar: [["TOAST_PLUG_JAR_1", :eyal], ["TOAST_PLUG_JAR_2", :eyal]]
  }.freeze
  CEREMONY = %w[TOAST_CEREMONY_1 TOAST_CEREMONY_2 TOAST_CEREMONY_3 TOAST_CEREMONY_4].freeze
  TICK_SE = "Battle catch click"
  POP_SE = "Vending machine dispense"
  CEREMONY_ME = "Slots big win"

  # "Not yet" or Back: nothing changes, the toaster stays in the bag.
  def self.finale(st)
    lines(FINALE, :eyal)
    plug = ToasterRules.plug_for(choose("TOAST_PLUG_ASK", :eyal, PLUG_CHOICES))
    return say("TOAST_PLUG_NOTYET", :eyal) unless plug
    return unless ToasterRules.deliver!(st, $bag, plug)
    PLUG_LINES[plug].each { |key, speaker| say(key, speaker) }
    pop
    say("TOAST_END_RECEIVED")
    pbMEPlay(CEREMONY_ME)
    lines(CEREMONY, :eyal)
    give_crumb(st)
  end

  # Tick, tick, pop and a white flash.
  def self.pop
    DesertTalk.name_key = nil if defined?(DesertTalk)
    2.times do
      pbSEPlay(TICK_SE)
      pbWait(0.5)
    end
    pbSEPlay(POP_SE)
    $game_screen.start_flash(Color.new(255, 255, 255, 255), 10) if $game_screen
    pbWait(0.5)
  end

  def self.give_crumb(st)
    announce(ToasterRules::CRUMB) if ToasterRules.crumb!(st, $bag)
  end

  # The game stopped between deliver! and crumb!: one line, then the crumb. No replay.
  def self.crumb_recover(st)
    say("TOAST_CRUMB_RECOVER", :eyal)
    give_crumb(st)
  end
end
