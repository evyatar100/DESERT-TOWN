#===============================================================================
# DJ Rush Hour (TG40) - pure rules: the sliding board, its BFS, and the quest state.
# No messages, graphics or audio. A bag is anything with quantity/add/remove.
#===============================================================================

module DJRushRules
  SIZE = 6
  EXIT_ROW = 2
  CAR = "A"
  # D8: board strings; "." empty, "A" the art car, lowercase letters the crowd.
  LEVELS = [
    %w[...... ...b.. AA.b.c ....dc eee.d. ......],
    %w[.dd..b ..gccb AAg..b ..hf.. ..hfee ..h...],
    %w[ggg.eh ....eh AAj.ed .bj..d .bcccd .b.ff.]
  ].freeze
  MIN_MOVES = [3, 8, 15].freeze
  KINDS = { [2, true] => :couple, [2, false] => :sleeper, [3, true] => :conga, [3, false] => :queue }.freeze
  FACES = { car: 0, couple: 2, sleeper: 1, conga: 3, queue: 3 }.freeze
  DIRS = { left: [-1, 0], right: [1, 0], up: [0, -1], down: [0, 1] }.freeze
  # Party crowd pool (D6): the dt_ ids on Map093 minus Ido, Evyatar, Johnny, She Se (fc898478).
  CROWD_POOL = %w[
    013feab1 0211e32a 0552d83f 0f0fdcf5 110ffafa 11eaf4fa 1988218f 2054a176 207a26e8 2082afb4
    266d65c6 2f88eb7f 305385c5 30c62b46 326f5ab5 3cdacb96 4c6540a3 50d0eeb7 5cb9ff14 648b924a 6a9c3d6f
    788b2614 7c875377 82451b58 834aef17 85acb2b8 8dafb982 8f6972ef 92958f4d 937a4a9a 963c65ea
    9b3660d1 a003ee69 a01046dc a7ba5185 abd7f899 b19b1f15 b3178e6b b5fa3a91 c11768dc c626f0d6
    d4540277 d472e0a3 d6ad577a e19726f0 e9da20da fc5dfab1 fcba2ff5 ff8eab6b
  ].freeze
  REACTIONS = {
    couple: %w[DJRUSH_R_COUPLE_1 DJRUSH_R_COUPLE_2 DJRUSH_R_COUPLE_3],
    sleeper: %w[DJRUSH_R_SLEEPER_1 DJRUSH_R_SLEEPER_2 DJRUSH_R_SLEEPER_3],
    conga: %w[DJRUSH_R_CONGA_1 DJRUSH_R_CONGA_2 DJRUSH_R_CONGA_3],
    queue: %w[DJRUSH_R_QUEUE_1 DJRUSH_R_QUEUE_2 DJRUSH_R_QUEUE_3],
    car: %w[DJRUSH_R_CAR_1 DJRUSH_R_CAR_2],
    bump: %w[DJRUSH_R_BUMP_1 DJRUSH_R_BUMP_2 DJRUSH_R_BUMP_3]
  }.freeze

  STAGES = %i[none intro freed bag done].freeze
  ITEM = :MUSICBAG
  JOHNNY = "4b08e38a"
  PLAYA_MAP = 98
  PARTY_MAP = 93
  # D3: fixed menu order, the right phrase second.
  SAY_KEYS = %w[DJRUSH_SAY_WRONG_1 DJRUSH_SAY_PHRASE DJRUSH_SAY_WRONG_2 DJRUSH_SAY_NOTHING].freeze
  PHRASE_INDEX = 1
  # TG53/TG56: Ido DJs the stage tile until :freed, then She Se, Ido goes to the floor; before that the crowd complains.
  IDO = "cace0cde"
  STAGE_TILE = [33, 12].freeze
  IDO_FLOOR = [[35, 19], [36, 19]].freeze
  COMPLAIN_IDS = (CROWD_POOL - %w[207a26e8]).freeze   # 207a26e8 opens a duel (quest NPC)
  COMPLAIN_KEYS = (1..6).map { |i| "DJRUSH_COMPLAIN_#{i}" }.freeze

  #-----------------------------------------------------------------------------
  # Board
  #-----------------------------------------------------------------------------
  # letter -> {x:, y:, len:, horiz:, kind:}, letters sorted ("A" first).
  def self.parse(rows)
    cells = {}
    rows.each_with_index do |row, y|
      row.each_char.with_index { |ch, x| (cells[ch] ||= []) << [x, y] unless ch == "." }
    end
    cells.keys.sort.to_h do |ch|
      cs = cells[ch]
      horiz = cs.map(&:last).uniq.length == 1
      len = cs.length
      kind = ch == CAR ? :car : KINDS[[len, horiz]]
      [ch, { x: cs.map(&:first).min, y: cs.map(&:last).min, len: len, horiz: horiz, kind: kind }]
    end
  end

  def self.new_board(level)
    { level: level, pieces: parse(LEVELS[level]), moves: 0, grab: nil, grab_from: nil }
  end

  def self.pos(piece) = piece[:horiz] ? piece[:x] : piece[:y]

  def self.cells(piece, at = pos(piece))
    piece[:horiz] ? (0...piece[:len]).map { |i| [at + i, piece[:y]] } : (0...piece[:len]).map { |i| [piece[:x], at + i] }
  end

  def self.occupied(board, skip = nil)
    occ = {}
    board[:pieces].each { |id, p| cells(p).each { |c| occ[c] = id } unless id == skip }
    occ
  end

  def self.piece_at(board, x, y) = occupied(board)[[x, y]]

  # :ok, or why one cell along dir is impossible (:cross, :edge, :blocked). Only the next cell is checked.
  def self.slide_check(board, id, dir)
    p = board[:pieces][id]
    dx, dy = DIRS[dir] || [0, 0]
    return :cross if p.nil? || (dx.zero? && dy.zero?) || (p[:horiz] ? dy != 0 : dx != 0)
    at = pos(p) + dx + dy
    return :edge if at < 0 || at + p[:len] > SIZE
    occ = occupied(board, id)
    cells(p, at).any? { |c| occ[c] } ? :blocked : :ok
  end

  # One cell along the axis: :moved, or the slide_check reason.
  def self.slide(board, id, dir)
    why = slide_check(board, id, dir)
    return why unless why == :ok
    p = board[:pieces][id]
    dx, dy = DIRS[dir]
    p[:horiz] ? p[:x] += dx : p[:y] += dy
    :moved
  end

  def self.open_dirs(board, id)
    p = board[:pieces][id]
    return [] unless p
    (p[:horiz] ? %i[left right] : %i[up down]).select { |d| slide_check(board, id, d) == :ok }
  end

  def self.grab(board, id)
    return false unless board[:pieces][id] && board[:grab].nil?
    board[:grab] = id
    board[:grab_from] = pos(board[:pieces][id])
    true
  end

  # Ends the grab; true when it counted as a move (net displacement not 0).
  def self.release(board)
    id = board[:grab]
    return false unless id
    moved = pos(board[:pieces][id]) != board[:grab_from]
    board[:moves] += 1 if moved
    board[:grab] = board[:grab_from] = nil
    moved
  end

  def self.solved?(board) = board[:pieces][CAR][:x] + board[:pieces][CAR][:len] == SIZE

  def self.restart(board) = board.replace(new_board(board[:level]))

  def self.key(board) = board[:pieces].values.map { |p| pos(p) }

  def self.cursor(at, dir)
    dx, dy = DIRS[dir] || [0, 0]
    [(at[0] + dx).clamp(0, SIZE - 1), (at[1] + dy).clamp(0, SIZE - 1)]
  end

  #-----------------------------------------------------------------------------
  # Search (a move = one grab and release, any distance)
  #-----------------------------------------------------------------------------
  # [[id, fixed, len, horiz], ...] in key order; the search works on keys and a 36-cell grid.
  def self.shape(board) = board[:pieces].map { |id, p| [id, p[:horiz] ? p[:y] : p[:x], p[:len], p[:horiz]] }

  def self.grid(shape, key)
    g = Array.new(SIZE * SIZE, false)
    shape.each_with_index do |(_, fixed, len, horiz), i|
      len.times { |j| g[horiz ? fixed * SIZE + key[i] + j : (key[i] + j) * SIZE + fixed] = true }
    end
    g
  end

  # [[id, delta, key], ...] for every one-grab move from key.
  def self.next_moves(shape, key)
    g = grid(shape, key)
    out = []
    shape.each_with_index do |(id, fixed, len, horiz), i|
      free = ->(at) { at.between?(0, SIZE - 1) && !g[horiz ? fixed * SIZE + at : at * SIZE + fixed] }
      [-1, 1].each do |sign|
        delta = 0
        delta += sign while free.(sign < 0 ? key[i] + delta - 1 : key[i] + len - 1 + delta + 1)
        (1..delta.abs).each do |d|
          n = key.dup
          n[i] += d * sign
          out << [id, d * sign, n]
        end
      end
    end
    out
  end

  # A shortest list of [id, delta] from the board's current position; [] when solved.
  def self.bfs_path(board)
    sh = shape(board)
    car = sh.index { |s| s[0] == CAR }
    origin = key(board)
    prev = { origin => nil }
    queue = [origin]
    until queue.empty?
      k = queue.shift
      if k[car] + sh[car][2] == SIZE
        path = []
        while (step = prev[k])
          path.unshift(step[1, 2])
          k = step[0]
        end
        return path
      end
      next_moves(sh, k).each do |id, delta, n|
        next if prev.key?(n)
        prev[n] = [k, id, delta]
        queue << n
      end
    end
    nil
  end

  def self.hint(board) = bfs_path(board)&.first

  def self.min_moves(level) = bfs_path(new_board(level)).length

  # Charset ids per piece letter; deterministic, never repeated inside a level (stride 8 is coprime to 49).
  def self.crowd_ids(level)
    slot = 0
    parse(LEVELS[level]).to_h do |id, p|
      ids = Array.new(FACES[p[:kind]]) do
        slot += 1
        CROWD_POOL[(level * 16 + (slot - 1) * 8) % CROWD_POOL.length]
      end
      [id, ids]
    end
  end

  # D7 reactions: always on the first move of a kind per board, else 50%; never the same key twice in a row.
  def self.reaction_key(kind, first, last_key, roll)
    return nil unless first || roll < 0.5
    pool = REACTIONS[kind] - [last_key]
    pool[(roll * 1000).floor % pool.length]
  end

  #-----------------------------------------------------------------------------
  # Quest state ($PokemonGlobal.dj_rush)
  #-----------------------------------------------------------------------------
  def self.new_state = { stage: :none, cleared: 0, best: [nil, nil, nil] }

  # Repairs in place so the saved hash stays the one the game holds.
  def self.normalize(state)
    return new_state unless state.is_a?(Hash)
    state.keys.each { |k| state.delete(k) unless %i[stage cleared best].include?(k) }
    state[:stage] = :none unless STAGES.include?(state[:stage])
    state[:cleared] = state[:cleared].is_a?(Integer) ? state[:cleared].clamp(0, 3) : 0
    best = state[:best].is_a?(Array) && state[:best].length == 3 ? state[:best] : [nil, nil, nil]
    state[:best] = best.each_with_index.map { |v, i| v.is_a?(Integer) && v >= MIN_MOVES[i] ? v : nil }
    state
  end

  def self.rank(stage) = STAGES.index(stage)
  def self.held?(bag) = !!(bag && bag.quantity(ITEM) > 0)
  def self.freed?(state) = rank(state[:stage]) >= rank(:freed)

  # A random complaint, never the one shown last.
  def self.complaint_key(last_key, roll)
    pool = COMPLAIN_KEYS - [last_key]
    pool[(roll * 1000).floor % pool.length]
  end

  def self.complain?(state, map_id, id)
    map_id == PARTY_MAP && !freed?(state) && COMPLAIN_IDS.include?(id)
  end

  def self.ido_floor?(state, map_id, id)
    map_id == PARTY_MAP && freed?(state) && id == IDO
  end

  def self.car_decide(state, bag)
    case state[:stage]
    when :none then :intro
    when :intro then :prompt_again
    when :freed then :meet
    when :bag then held?(bag) ? :remind : :reissue
    else :after
    end
  end

  def self.crowd_decide(state)
    { none: :intro, intro: :prompt_again }[state[:stage]] || :gone
  end

  def self.johnny_decide(state, bag, map_id)
    case map_id
    when PLAYA_MAP
      return :menu if state[:stage] == :bag && held?(bag)
      return :after if state[:stage] == :done
    when PARTY_MAP
      return :hint if state[:stage] == :bag
    end
    nil
  end

  def self.say_result(index)
    return :phrase if index == PHRASE_INDEX
    [0, 2].include?(index) ? :wrong : :nothing
  end

  # Boards still to play in the main run.
  def self.levels_left(state) = (state[:cleared]...LEVELS.length).to_a

  #-----------------------------------------------------------------------------
  # Mutators: state and item change together, before any message.
  #-----------------------------------------------------------------------------
  def self.start!(state)
    return false unless state[:stage] == :none
    state[:stage] = :intro
    true
  end

  # First clear in order during :intro advances; a replay after :freed records best only.
  def self.clear_level!(state, i, moves)
    return false unless i.is_a?(Integer) && i.between?(0, 2) && moves.is_a?(Integer) && moves >= MIN_MOVES[i]
    if state[:stage] == :intro && i == state[:cleared]
      state[:cleared] = i + 1
    elsif !freed?(state)
      return false
    end
    state[:best][i] = [state[:best][i], moves].compact.min
    true
  end

  def self.free!(state)
    return false unless state[:stage] == :intro && state[:cleared] == 3
    state[:stage] = :freed
    true
  end

  def self.give_bag!(state, bag)
    return false unless state[:stage] == :freed && bag
    return false unless held?(bag) || bag.add(ITEM, 1)
    state[:stage] = :bag
    true
  end

  def self.reissue!(state, bag)
    return false unless state[:stage] == :bag && bag && !held?(bag)
    bag.add(ITEM, 1)
  end

  # Johnny keeps only the password on the tag and hands the bag back (founder, TG40):
  # exactly one copy is held after :done, and nothing ever adds another.
  def self.deliver!(state, bag)
    return false unless state[:stage] == :bag && held?(bag)
    n = bag.quantity(ITEM)
    return false unless bag.remove(ITEM, n)
    unless bag.add(ITEM, 1)
      bag.add(ITEM, n)   # roll back: the bag is never lost and the stage stays :bag
      return false
    end
    state[:stage] = :done
    true
  end

  def self.delivered?(state) = state[:stage] == :done

  # F9 only: that stage, holding one bag in :bag and :done (Johnny hands it back), none before.
  def self.debug_set!(state, bag, stage)
    return false unless STAGES.include?(stage) && bag
    bag.remove(ITEM, bag.quantity(ITEM)) if held?(bag)
    bag.add(ITEM, 1) if %i[bag done].include?(stage)
    state[:stage] = stage
    state[:cleared] = rank(stage) >= rank(:freed) ? 3 : 0
    true
  end
end
