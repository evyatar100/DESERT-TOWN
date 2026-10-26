#===============================================================================
# TempleStickers - per-run state. One run = one Game.start_new; each run gets
# its own page on every board it sticks on. Core types only, so old saves load.
#===============================================================================

module TempleStickers
  # 4 stickers, exactly one per honoree, each uniform among that honoree's 3.
  def self.deal(rng = Random.new)
    HONOREES.map do |h|
      options = stickers_for(h)
      options[rng.rand(options.length)]
    end
  end

  def self.new_run_id(rng = Random.new)
    format("%08x%08x", rng.rand(2**32), rng.rand(2**32))
  end

  def self.new_run(rng = Random.new)
    {
      run_id: new_run_id(rng),
      hand: deal(rng),
      collected: [],
      placed: [],      # [[sticker_id, board_id], ...]
      name: nil,
      reward_shown: false
    }
  end

  # Repairs a loaded value; anything unusable becomes a fresh run.
  def self.normalize_run(value, rng = Random.new)
    return new_run(rng) unless value.is_a?(Hash)
    return new_run(rng) unless value[:run_id].is_a?(String) && !value[:run_id].empty?
    hand = Array(value[:hand]).select { |s| STICKERS.key?(s) }
    return new_run(rng) unless hand.length == HONOREES.length
    {
      run_id: value[:run_id],
      hand: hand,
      collected: Array(value[:collected]).select { |s| hand.include?(s) }.uniq,
      placed: Array(value[:placed]).select { |p| p.is_a?(Array) && hand.include?(p[0]) && board?(p[1]) },
      name: value[:name].is_a?(String) ? value[:name] : nil,
      reward_shown: value[:reward_shown] == true
    }
  end

  # Collected and not yet placed, in hand order.
  def self.placeable(run)
    done = run[:placed].map { |p| p[0] }
    run[:hand].select { |s| run[:collected].include?(s) && !done.include?(s) }
  end

  # Gives a hand sticker; false when not in hand or already collected.
  def self.collect(run, sticker_id)
    return false unless run[:hand].include?(sticker_id)
    return false if run[:collected].include?(sticker_id)
    run[:collected] << sticker_id
    true
  end

  # A placement is final: false when the sticker cannot be placed now.
  def self.record_placement(run, sticker_id, board_id)
    return false unless board?(board_id)
    return false unless placeable(run).include?(sticker_id)
    run[:placed] << [sticker_id, board_id.to_s]
    true
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
