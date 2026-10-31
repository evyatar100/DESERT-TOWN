#===============================================================================
# PlayLog — cabinet counters outside the save file.
#
# Counts survive New Game and power cuts. play_log.txt in the game folder is
# rewritten after every bump. A write error is ignored so the cabinet keeps
# running.
#
#   players      first color-button press after IDLE_SECONDS with no press
#   maps         each arrival on a map (same id twice in a row does not count)
#   messages     each pbMessage / string pbShowCommands, keyed by translation
#   characters   each confirmed DesertCharSelect.apply! pick
#===============================================================================

module PlayLog
  IDLE_SECONDS = 3 * 60
  LOG_FILE = "play_log.txt"
  RECENT_LIMIT = 32

  #-----------------------------------------------------------------------------
  # Pure helpers (covered by tests/plugin_rules_test.rb)
  #-----------------------------------------------------------------------------

  # True when this press starts a new player session.
  # now / last_press may be Time or epoch seconds.
  def self.new_player?(now, last_press, idle = IDLE_SECONDS)
    return false if now.nil?
    return true if last_press.nil?
    now_t = now.respond_to?(:to_f) ? now.to_f : now
    last_t = last_press.respond_to?(:to_f) ? last_press.to_f : last_press
    return (now_t - last_t) >= idle
  end

  # True when arriving on new_id should bump the map counter.
  def self.count_map_visit?(old_id, new_id)
    return false if new_id.nil? || new_id == 0
    return true if old_id.nil? || old_id == 0
    return old_id != new_id
  end

  # Strip Essentials window control codes for a stable non-key message id.
  def self.strip_controls(text)
    return "" if text.nil?
    s = text.to_s.dup
    s.gsub!(/\\[A-Za-z]+(\[[^\]]*\])?/, "")
    s.gsub!(/\s+/, " ")
    return s.strip
  end

  def self.translation_key?(key)
    return false unless key.is_a?(String)
    return !!(key.match?(/\A[A-Z][A-Z0-9_]*\z/))
  end

  # Resolve the count key for a message box. recent is [[key, returned_text], ...]
  # oldest first; the newest matching _INTL wins.
  def self.message_key(box_text, recent)
    box = box_text.to_s
    Array(recent).reverse_each do |key, text|
      next unless text.to_s == box || strip_controls(text) == strip_controls(box)
      return key.to_s if translation_key?(key.to_s)
    end
    stripped = strip_controls(box)
    return stripped if translation_key?(stripped)
    return stripped
  end

  def self.empty_state
    return {
      players: 0,
      last_press: nil,
      maps: {},
      messages: {},
      characters: {}
    }
  end

  def self.bump_count(hash, key)
    k = key.to_s
    hash = {} if hash.nil?
    hash[k] = (hash[k] || 0) + 1
    return hash
  end

  # Parse the on-disk text into a state hash. last_press is a Time or nil.
  def self.parse(text)
    data = empty_state
    return data if text.nil? || text.empty?
    section = nil
    text.to_s.each_line do |raw|
      line = raw.strip
      next if line.empty?
      case line
      when "maps"
        section = :maps
      when "messages"
        section = :messages
      when "characters"
        section = :characters
      else
        if section.nil?
          if line =~ /\Aplayers\t(\d+)\z/
            data[:players] = $1.to_i
          elsif line =~ /\Alast_press\t(.+)\z/
            data[:last_press] = parse_time($1)
          end
        elsif line =~ /\A(.+)\t(\d+)\z/
          data[section][$1] = $2.to_i
        end
      end
    end
    return data
  end

  def self.parse_time(s)
    return nil if s.nil? || s.empty?
    return nil unless s =~ /\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z\z/
    return Time.utc($1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i)
  rescue StandardError
    return nil
  end

  def self.format_time(t)
    return "" if t.nil?
    return t.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  # Serialize state to the on-disk text. Keys in each section are sorted.
  def self.format(data)
    data = empty_state if data.nil?
    lines = []
    lines << "players\t#{data[:players].to_i}"
    lines << "last_press\t#{format_time(data[:last_press])}" if data[:last_press]
    lines << ""
    lines << "maps"
    (data[:maps] || {}).keys.map(&:to_s).sort.each do |k|
      lines << "#{k}\t#{data[:maps][k].to_i}"
    end
    lines << ""
    lines << "messages"
    (data[:messages] || {}).keys.map(&:to_s).sort.each do |k|
      lines << "#{k}\t#{data[:messages][k].to_i}"
    end
    lines << ""
    lines << "characters"
    (data[:characters] || {}).keys.map(&:to_s).sort.each do |k|
      lines << "#{k}\t#{data[:characters][k].to_i}"
    end
    lines << ""
    return lines.join("\n")
  end

  #-----------------------------------------------------------------------------
  # State and file I/O
  #-----------------------------------------------------------------------------

  def self.log_path
    return @log_path || LOG_FILE
  end

  def self.log_path=(path)
    @log_path = path
  end

  def self.state
    load! unless @loaded
    return @state
  end

  # Tests point log_path at a temp file and call this so nothing hits the game folder.
  def self.reset_for_tests!
    @loaded = true
    @state = empty_state
    @recent = []
  end

  def self.load!
    @loaded = true
    @recent ||= []
    path = log_path
    if file_exist?(path)
      @state = parse(File.read(path))
    else
      @state = empty_state
    end
  rescue StandardError
    @state = empty_state
    @recent ||= []
  end

  def self.file_exist?(path)
    return FileTest.exist?(path) if defined?(FileTest) && FileTest.respond_to?(:exist?)
    return File.exist?(path) if defined?(File) && File.respond_to?(:exist?)
    false
  end

  def self.persist!
    write_file(log_path, format(state))
  end

  def self.write_file(path, text)
    tmp = "#{path}.tmp"
    File.open(tmp, "wb") { |f| f.write(text) }
    File.rename(tmp, path)
  rescue StandardError
    nil
  end

  def self.remember_intl(key, text)
    @recent ||= []
    @recent << [key.to_s, text.to_s]
    @recent.shift while @recent.length > RECENT_LIMIT
  end

  def self.recent_intl
    return @recent || []
  end

  #-----------------------------------------------------------------------------
  # Counters
  #-----------------------------------------------------------------------------

  def self.color_key_triggered?
    return false unless defined?(DesertTownControls)
    return false unless defined?(Input) && Input.respond_to?(:triggerex?)
    DesertTownControls::COLORS.each_value do |spec|
      return true if Input.triggerex?(spec[:key])
    end
    false
  end

  def self.note_input_frame
    return unless color_key_triggered?
    now = Time.now
    st = state
    if new_player?(now, st[:last_press])
      st[:players] = st[:players].to_i + 1
    end
    st[:last_press] = now
    persist!
  end

  def self.note_map(map_id)
    st = state
    st[:maps] = bump_count(st[:maps], map_id)
    persist!
  end

  def self.note_message(box_text)
    return if box_text.nil?
    return unless box_text.is_a?(String)
    key = message_key(box_text, recent_intl)
    return if key.nil? || key.empty?
    st = state
    st[:messages] = bump_count(st[:messages], key)
    persist!
  end

  def self.note_character(char_id)
    return if char_id.nil? || char_id.to_s.empty?
    st = state
    st[:characters] = bump_count(st[:characters], char_id)
    persist!
  end
end

#===============================================================================
# Hooks
#===============================================================================

if defined?(Input)
  module Input
    class << self
      alias play_log_input_update update
      def update(*args)
        play_log_input_update(*args)
        PlayLog.note_input_frame
      end
    end
  end
end

if defined?(EventHandlers)
  EventHandlers.add(:on_enter_map, :play_log_map_visit,
    proc { |old_map_id|
      next unless defined?($game_map) && $game_map
      new_id = $game_map.map_id
      next unless PlayLog.count_map_visit?(old_map_id, new_id)
      PlayLog.note_map(new_id)
    }
  )
end

if defined?(_INTL)
  alias _play_log_intl _INTL
  def _INTL(message, *arg)
    ret = _play_log_intl(message, *arg)
    PlayLog.remember_intl(message, ret) if defined?(PlayLog)
    return ret
  end
end

if defined?(pbMessage)
  alias _play_log_pbMessage pbMessage
  def pbMessage(message, *args, &block)
    PlayLog.note_message(message) if defined?(PlayLog)
    return _play_log_pbMessage(message, *args, &block)
  end
end

if defined?(pbShowCommands)
  alias _play_log_pbShowCommands pbShowCommands
  def pbShowCommands(arg0, *args, &block)
    # pbMessage passes a window; a string message is a standalone choice box.
    PlayLog.note_message(arg0) if defined?(PlayLog) && arg0.is_a?(String)
    return _play_log_pbShowCommands(arg0, *args, &block)
  end
end

if defined?(DesertCharSelect) && DesertCharSelect.respond_to?(:apply!)
  module DesertCharSelect
    class << self
      alias_method :_play_log_apply!, :apply! unless method_defined?(:_play_log_apply!)
      def apply!(entry)
        ret = _play_log_apply!(entry)
        if defined?(PlayLog) && entry.is_a?(Hash) && entry[:id]
          PlayLog.note_character(entry[:id])
        end
        return ret
      end
    end
  end
end
