#===============================================================================
# Toaster (TG9) - pure quest rules: state, decisions and the only mutators.
# No messages, graphics or audio. A bag is anything with quantity/add/remove.
#===============================================================================

module ToasterRules
  STAGES = %i[none asked lead permit toaster done].freeze
  PLUGS = [nil, :ac, :jar].freeze
  PERMIT = :TOASTPERMIT
  TOASTER = :TOASTER
  CRUMB = :TOASTCRUMB
  ITEMS = [PERMIT, TOASTER, CRUMB].freeze
  ROTOM_LEVEL = 70
  ROTOM_FORM = 1
  ROTOM_MOVES = %i[OVERHEAT THUNDERBOLT WILLOWISP CONFUSERAY].freeze
  BATTLE_RULES = %w[canLose disablePokeBalls noExp].freeze
  # Win and loss both leave the casino here (the mummy-death tile).
  OUT_MAP = 80
  OUT_X = 8
  OUT_Y = 15
  OUT_DIR = 2
  ALTAR_ART = "toaster_altar"
  ALTAR_FALLBACK = "Object ball"
  JUMP_STAGES = %i[asked lead permit toaster].freeze

  def self.new_state
    { stage: :none, crumb_given: false, plug: nil }
  end

  # Repairs in place so the saved hash stays the one the game holds.
  def self.normalize(state)
    return new_state unless state.is_a?(Hash)
    state.keys.each { |k| state.delete(k) unless %i[stage crumb_given plug].include?(k) }
    state[:stage] = :none unless STAGES.include?(state[:stage])
    state[:crumb_given] = state[:crumb_given] == true
    state[:plug] = nil unless PLUGS.include?(state[:plug])
    state
  end

  def self.held?(bag, item)
    bag && bag.quantity(item) > 0
  end

  #-----------------------------------------------------------------------------
  # Decisions
  #-----------------------------------------------------------------------------
  def self.eyal_decide(state, bag)
    case state[:stage]
    when :none then :intro
    when :asked then :remind_noodles
    when :lead then :remind_clerk
    when :permit then :remind_vault
    when :toaster then held?(bag, TOASTER) ? :finale : :remind_altar
    else state[:crumb_given] ? :after : :crumb_recover
    end
  end

  def self.noodles_decide(state)
    case state[:stage]
    when :none then :plain
    when :asked then :duel
    when :done then :after
    else :remind
    end
  end

  def self.clerk_decide(state, bag)
    case state[:stage]
    when :none, :asked then :plain
    when :lead then :hearing
    when :permit then held?(bag, PERMIT) ? :remind : :reissue
    else :closed
    end
  end

  def self.altar_decide(state, bag)
    case state[:stage]
    when :permit then :fight
    when :toaster then held?(bag, TOASTER) ? :empty : :regive
    when :done then :empty
    else :sealed
    end
  end

  # Page graphic for the altar: empty exactly when the decision is :empty.
  def self.altar_graphic(decision, art_present)
    return "" if decision == :empty
    art_present ? ALTAR_ART : ALTAR_FALLBACK
  end

  def self.battle_won?(outcome)
    outcome == 1
  end

  def self.oren_after?(state)
    state[:stage] == :done && state[:plug] == :ac
  end

  # Plug menu index -> plug; "not yet" (2) and cancel give nil.
  def self.plug_for(pick)
    { 0 => :ac, 1 => :jar }[pick]
  end

  # Yunik's own talk page: Action trigger (0) and his speaker/text commands (355/101).
  def self.talk_page?(trigger, commands, speaker, msg)
    return false unless trigger == 0
    commands.any? do |code, params|
      text = params[0].to_s
      (code == 355 && text.include?(speaker)) || (code == 101 && text.include?(msg))
    end
  end

  # Where to put one injected script command: before the page's closing end command.
  def self.inject_index(codes)
    return nil if codes.empty?
    codes.last == 0 ? codes.length - 1 : codes.length
  end

  #-----------------------------------------------------------------------------
  # Mutators: item change and stage change together, before any message.
  #-----------------------------------------------------------------------------
  def self.ask!(state)
    return false unless state[:stage] == :none
    state[:stage] = :asked
    true
  end

  def self.lead!(state)
    return false unless state[:stage] == :asked
    state[:stage] = :lead
    true
  end

  def self.permit!(state, bag)
    return false unless state[:stage] == :lead && bag
    return false unless held?(bag, PERMIT) || bag.add(PERMIT, 1)
    state[:stage] = :permit
    true
  end

  def self.reissue!(state, bag)
    return false unless state[:stage] == :permit && bag && !held?(bag, PERMIT)
    bag.add(PERMIT, 1)
  end

  def self.claim!(state, bag)
    return false unless state[:stage] == :permit && bag
    return false unless held?(bag, TOASTER) || bag.add(TOASTER, 1)
    bag.remove(PERMIT, bag.quantity(PERMIT)) if held?(bag, PERMIT)
    state[:stage] = :toaster
    true
  end

  def self.regive!(state, bag)
    return false unless state[:stage] == :toaster && bag && !held?(bag, TOASTER)
    bag.add(TOASTER, 1)
  end

  def self.deliver!(state, bag, plug)
    return false unless state[:stage] == :toaster && %i[ac jar].include?(plug) && held?(bag, TOASTER)
    return false unless bag.remove(TOASTER, bag.quantity(TOASTER))
    state[:plug] = plug
    state[:stage] = :done
    true
  end

  def self.crumb!(state, bag)
    return false unless state[:stage] == :done && !state[:crumb_given] && bag
    return false unless bag.add(CRUMB, 1)
    state[:crumb_given] = true
    true
  end

  # F9 only: that stage, holding exactly that stage's item. Never :done.
  def self.debug_jump!(state, bag, stage)
    return false unless JUMP_STAGES.include?(stage) && bag
    ITEMS.each { |i| bag.remove(i, bag.quantity(i)) if held?(bag, i) }
    bag.add(PERMIT, 1) if stage == :permit
    bag.add(TOASTER, 1) if stage == :toaster
    state.replace(new_state.merge(stage: stage))
    true
  end
end
