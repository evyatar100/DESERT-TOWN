#===============================================================================
# AllaStand (TG21/TG23) - pure quest rules: state, decisions and the only mutators.
# No messages, graphics or audio. A bag is anything with quantity/add. Python mirror: tests/alla_rules.py.
#===============================================================================

module AllaRules
  STAGES = %i[none campaign rush done].freeze
  CAMPERS = %i[tal elias mario].freeze
  VOTES_NEEDED = 3
  ITEM = :ALLAHOTDOG
  # "campaign + 3 votes" is a campaign with every vote in.
  JUMP_STAGES = %i[campaign campaign_votes rush done].freeze

  def self.new_state
    { stage: :none, votes: [], hotdog_given: false }
  end

  # Repairs in place so the saved hash stays the one the game holds.
  def self.normalize(state)
    return new_state unless state.is_a?(Hash)
    state.keys.each { |k| state.delete(k) unless %i[stage votes hotdog_given].include?(k) }
    state[:stage] = :none unless STAGES.include?(state[:stage])
    votes = state[:votes].is_a?(Array) ? state[:votes] : []
    state[:votes] = CAMPERS.select { |c| votes.include?(c) }
    state[:hotdog_given] = state[:hotdog_given] == true
    state
  end

  def self.held?(bag, item)
    bag && bag.quantity(item) > 0
  end

  #-----------------------------------------------------------------------------
  # Decisions
  #-----------------------------------------------------------------------------
  def self.alla_decide(state)
    case state[:stage]
    when :none then :intro
    when :campaign then state[:votes].length >= VOTES_NEEDED ? :count : :remind
    when :rush then :rush
    else state[:hotdog_given] ? :after : :hotdog_recover
    end
  end

  # after_heard: this camper's after line was already said this session.
  def self.camper_decide(state, who, after_heard = false)
    return :plain unless CAMPERS.include?(who)
    case state[:stage]
    when :campaign then state[:votes].include?(who) ? :voted : :vote
    when :done then after_heard ? :plain : :after
    else :plain
    end
  end

  def self.missing(state)
    CAMPERS - state[:votes]
  end

  #-----------------------------------------------------------------------------
  # Mutators: state change (and the item) together, before any message.
  #-----------------------------------------------------------------------------
  def self.campaign!(state)
    return false unless state[:stage] == :none
    state[:stage] = :campaign
    true
  end

  def self.vote!(state, who)
    return false unless state[:stage] == :campaign && CAMPERS.include?(who)
    return false if state[:votes].include?(who)
    state[:votes] << who
    true
  end

  def self.count!(state)
    return false unless state[:stage] == :campaign && state[:votes].length >= VOTES_NEEDED
    state[:stage] = :rush
    true
  end

  def self.open!(state)
    return false unless state[:stage] == :rush
    state[:stage] = :done
    true
  end

  # The flag and the item together; a copy already in the bag (F9 reset) is not doubled.
  def self.hotdog!(state, bag)
    return false unless state[:stage] == :done && !state[:hotdog_given] && bag
    return false unless held?(bag, ITEM) || bag.add(ITEM, 1)
    state[:hotdog_given] = true
    true
  end

  #-----------------------------------------------------------------------------
  # QuestMarks (TG65): Alla and the unvoted campers, Playa (98) only.
  #-----------------------------------------------------------------------------
  MARK_MAP = 98
  MARK_ALLA = "dt_4c4e039d"
  MARK_CAMPERS = { tal: "dt_9b3660d1", elias: "dt_788b2614", mario: "dt_bb70b1dd" }.freeze

  def self.marks(state, map_id)
    return {} unless map_id == MARK_MAP
    case state[:stage]
    when :none then { giver: [MARK_ALLA] }
    when :campaign
      return { next: [MARK_ALLA] } if state[:votes].length >= VOTES_NEEDED
      { next: missing(state).map { |c| MARK_CAMPERS[c] } }
    when :rush then { next: [MARK_ALLA] }
    else state[:hotdog_given] ? {} : { next: [MARK_ALLA] }
    end
  end

  # F9 only. :done counts as given when the bag already holds the item.
  def self.debug_jump!(state, stage, bag = nil)
    return false unless JUMP_STAGES.include?(stage)
    votes = %i[campaign_votes rush done].include?(stage) ? CAMPERS.dup : []
    real = stage == :campaign_votes ? :campaign : stage
    state.replace(new_state.merge(stage: real, votes: votes, hotdog_given: real == :done && held?(bag, ITEM) == true))
    true
  end
end
