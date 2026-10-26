#===============================================================================
# TempleStickers - per-run state. One run = one Game.start_new: the stickers
# collected (each sign gives its own) and placed, its name and Ido's visit.
# Pages on the wall are per Inception depth (004). Core types only.
#===============================================================================

module TempleStickers
  def self.new_run_id(rng = Random.new)
    format("%08x%08x", rng.rand(2**32), rng.rand(2**32))
  end

  def self.new_run(rng = Random.new)
    {
      run_id: new_run_id(rng),
      collected: [],
      placed: [],      # [[sticker_id, board_id], ...]
      name: nil,
      reward_shown: false
    }
  end

  # Repairs a loaded value; anything unusable becomes a fresh run. An old save's
  # :hand is dropped; its collected and placed stickers stay as they were.
  def self.normalize_run(value, rng = Random.new)
    return new_run(rng) unless value.is_a?(Hash)
    return new_run(rng) unless value[:run_id].is_a?(String) && !value[:run_id].empty?
    collected = Array(value[:collected]).map { |s| canonical(s) }.select { |s| STICKERS.key?(s) }.uniq
    placed = Array(value[:placed]).select { |p| p.is_a?(Array) }.map { |p| [canonical(p[0]), p[1]] }
    {
      run_id: value[:run_id],
      collected: collected,
      placed: placed.select { |p| collected.include?(p[0]) && board?(p[1]) }.uniq { |p| p[0] },
      name: value[:name].is_a?(String) ? value[:name] : nil,
      reward_shown: value[:reward_shown] == true
    }
  end

  # The hand: collected and not yet placed, in STICKERS (honoree) order.
  def self.placeable(run)
    done = run[:placed].map { |p| p[0] }
    STICKERS.keys.select { |s| run[:collected].include?(s) && !done.include?(s) }
  end

  # The placeable stickers whose home is this board; only these can go on it.
  def self.placeable_on(run, board_id)
    placeable(run).select { |s| home_board(s) == board_id.to_s }
  end

  # Home boards of the placeable stickers that do not fit board_id.
  def self.other_homes(run, board_id)
    (placeable(run) - placeable_on(run, board_id)).map { |s| home_board(s) }.uniq
  end

  # Gives a sticker once per run; false when unknown or already collected.
  def self.collect(run, sticker_id)
    return false unless STICKERS.key?(sticker_id)
    return false if run[:collected].include?(sticker_id)
    run[:collected] << sticker_id
    true
  end

  # A placement is final and only on the sticker's home board.
  def self.record_placement(run, sticker_id, board_id)
    return false unless placeable_on(run, board_id).include?(sticker_id)
    run[:placed] << [sticker_id, board_id.to_s]
    true
  end

  # Records a placement already stored on the wall (any board, e.g. an old cross-board item).
  def self.record_stored_placement(run, sticker_id, board_id)
    return false unless board?(board_id) && placeable(run).include?(sticker_id)
    run[:placed] << [sticker_id, board_id.to_s]
    true
  end

  # A sign gives its own sticker the first time in a run; later reads show text only.
  def self.read_sign(run, sticker_id)
    collect(run, sticker_id) ? :sticker : :fact
  end

  # The reward rule (confirmed by founder 2026-10-26): this run stuck at least one
  # sticker on each of the 4 boards.
  def self.reward_earned?(run)
    boards = run[:placed].map { |p| p[1] }
    HONOREES.all? { |b| boards.include?(b) }
  end

  # Ido's visit: reward earned, staff switch on, not yet shown this run.
  def self.reward_due?(run, reward_on)
    reward_on == true && !run[:reward_shown] && reward_earned?(run)
  end

  def self.mark_reward_shown(run)
    run[:reward_shown] = true
  end

  # The run's name, prefilled in later name keyboards. Nil or blank clears it.
  def self.set_name(run, name)
    name = name.to_s.strip
    run[:name] = name.empty? ? nil : name[0, NAME_MAX]
  end

  def self.run
    $temple_stickers = normalize_run($temple_stickers) unless $temple_stickers.is_a?(Hash) && $temple_stickers[:run_id]
    $temple_stickers
  end

  def self.start_new_run
    Staff.deactivate
    new_run
  end
end

$temple_stickers = nil

# No ensure_class: a save from before this plugin has no key and stays valid.
SaveData.register(:temple_stickers) do
  save_value { TempleStickers.run }
  load_value { |value| $temple_stickers = TempleStickers.normalize_run(value) }
  new_game_value { TempleStickers.start_new_run }
end
