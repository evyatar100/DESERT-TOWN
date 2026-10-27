#===============================================================================
# Toaster - the casino altar (Map094 ev9 runs pbToasterAltar), Yunik's Eviction
# (008_eviction.rb) and the way out to the Old City.
#===============================================================================

module Toaster
  ALTAR_EVENT = "toaster_altar"

  def self.altar_art?
    !!pbResolveBitmap("Graphics/Characters/#{ToasterRules::ALTAR_ART}")
  end

  # The one writer of the altar look, from the quest state.
  def self.altar_look
    ToasterRules.altar_graphic(ToasterRules.altar_decide(state, $bag), altar_art?)
  end

  # Sets the altar page graphic from the quest state before the events are built.
  def self.dress_altar(map)
    ev = map.events.values.find { |e| e.name == ALTAR_EVENT }
    return false unless ev
    look = altar_look
    ev.pages.each { |page| page.graphic.character_name = look }
    true
  end

  def self.altar_talk
    st = state
    case ToasterRules.altar_decide(st, $bag)
    when :sealed then say("TOAST_ALTAR_SEALED")
    when :fight then altar_fight(st)
    when :regive
      return unless ToasterRules.regive!(st, $bag)
      say("TOAST_ALTAR_REGIVE")
      announce(ToasterRules::TOASTER)
    else say("TOAST_ALTAR_EMPTY")
    end
  end

  VAULT_INTRO = %w[TOAST_ALTAR_POSSESSED_1 TOAST_ALTAR_POSSESSED_2 TOAST_VAULT_YUNIK_1 TOAST_VAULT_YUNIK_2].freeze

  # Beat 3: sparks and the full intro once a session, then the Eviction until a win or "no".
  def self.altar_fight(st)
    vault_intro
    loop do
      result = run_eviction
      return claim_toaster(st) if result[:won]
      break unless retry?("TOAST_RETRY_VAULT_ASK")
    end
    say("TOAST_ALTAR_LOSE")
    escort_out
  end

  # Later visits this session hear only Yunik's notice line.
  def self.vault_intro
    if @vault_seen
      say(VAULT_INTRO.last, :clerk)
      return
    end
    @vault_seen = true
    pbSEPlay("Voltorb Flip explosion")
    $game_screen.start_shake(5, 5, 20) if $game_screen
    lines(VAULT_INTRO[0, 2])
    lines(VAULT_INTRO[2, 2], :clerk)
  end

  def self.claim_toaster(st)
    if ToasterRules.claim!(st, $bag)
      live = $game_map.events.values.find { |e| e.name == ALTAR_EVENT }
      live.character_name = altar_look if live
      lines(%w[TOAST_ALTAR_WIN_1 TOAST_ALTAR_WIN_2])
      announce(ToasterRules::TOASTER)
      say("TOAST_GOT_TOASTER")
    end
    escort_out
  end

  # One eviction at the current easing; record: false for the F9 test run.
  def self.run_eviction(record: true)
    DesertTalk.name_key = nil if defined?(DesertTalk)
    start = ToasterEvictRules.start_h(vault_last_hits)
    result = EvictScene.new(vault_losses, start, rand(1 << 30)).run
    record_vault(result[:won], result[:hits]) if record
    result
  end

  # Win or "no": out to the Old City, the same tile a mummy touch lands on.
  def self.escort_out
    DesertTalk.name_key = nil if defined?(DesertTalk)
    pbFadeOutIn do
      pbTransferPlayer(ToasterRules::OUT_MAP, ToasterRules::OUT_X, ToasterRules::OUT_Y, ToasterRules::OUT_DIR)
    end
  end
end

def pbToasterAltar
  Toaster.altar_talk if Toaster.on_map?(Toaster::ALTAR_MAP)
  true
end

EventHandlers.add(:on_game_map_setup, :toaster_altar,
  proc { |map_id, map, _tileset|
    next if map_id != Toaster::ALTAR_MAP
    Toaster.dress_altar(map)
  }
)
