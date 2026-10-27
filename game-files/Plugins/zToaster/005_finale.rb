#===============================================================================
# Toaster - HaNoodles' finale at Kusomo: what to unplug, the pop, the fixed line,
# the ceremony and the framed crumb. deliver! -> pop -> END line -> ceremony -> crumb!.
#===============================================================================

module Toaster
  FINALE = %w[TOAST_NOODLE_FINALE_1 TOAST_NOODLE_FINALE_2 TOAST_NOODLE_FINALE_3].freeze
  PLUG_CHOICES = %w[TOAST_PLUG_CHOICE_AC TOAST_PLUG_CHOICE_POT TOAST_PLUG_CHOICE_NOTYET].freeze
  # [key, speaker] per plug; Oren howls offscreen; [:wait3] is 3 s of silence.
  PLUG_LINES = {
    ac: [["TOAST_PLUG_AC_1", :noodles], ["TOAST_PLUG_AC_2", :oren]],
    pot: [["TOAST_PLUG_POT_1", :noodles], [:wait3], ["TOAST_PLUG_POT_2", :noodles]]
  }.freeze
  CEREMONY = %w[TOAST_CEREMONY_1 TOAST_CEREMONY_2 TOAST_CEREMONY_3 TOAST_CEREMONY_4].freeze
  TICK_SE = "Battle catch click"
  POP_SE = "Vending machine dispense"
  CEREMONY_ME = "Slots big win"

  # "Not yet" or Back: nothing changes, the toaster stays in the bag.
  def self.finale(st)
    lines(FINALE, :noodles)
    plug = ToasterRules.plug_for(choose("TOAST_PLUG_ASK", :noodles, PLUG_CHOICES))
    return say("TOAST_PLUG_NOTYET", :noodles) unless plug
    return unless ToasterRules.deliver!(st, $bag, plug)
    PLUG_LINES[plug].each { |key, speaker| key == :wait3 ? plug_pause : say(key, speaker) }
    pop
    say("TOAST_END_RECEIVED")
    pbMEPlay(CEREMONY_ME)
    lines(CEREMONY, :noodles)
    give_crumb(st)
  end

  def self.plug_pause
    DesertTalk.name_key = nil if defined?(DesertTalk)
    pbWait(3.0)
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
    say("TOAST_CRUMB_RECOVER", :noodles)
    give_crumb(st)
  end
end
