#===============================================================================
# QuestMarks - client registry. Each quest registers one block: map_id -> {next:, giver:}.
# A client that raises is logged once and switched off for the session; nothing is saved.
#===============================================================================

module QuestMarks
  @clients = {}
  @disabled = {}
  @givers = nil

  # Re-registering a key replaces it and re-enables it.
  def self.register(key, &blk)
    return unless blk
    @clients[key] = blk
    @disabled.delete(key)
  end

  def self.clients = @clients.keys
  def self.disabled?(key) = @disabled.key?(key)

  def self.givers? = @givers.nil? ? GIVERS : @givers

  # Session only (F9); nil goes back to the GIVERS default.
  def self.givers=(value)
    @givers = value
  end

  # key -> the client's hash for this map; a broken or non-hash result counts as {}.
  def self.results(map_id)
    out = {}
    @clients.each do |key, blk|
      next if @disabled.key?(key)
      begin
        res = blk.call(map_id)
        out[key] = res.is_a?(Hash) ? res : {}
      rescue StandardError => e
        @disabled[key] = true
        echoln("[QuestMarks] client #{key} disabled: #{e.class}: #{e.message}") if defined?(echoln)
      end
    end
    out
  end

  # Event name -> sorted ids of the events on this map (built once per map by the overlay).
  def self.names_index(events)
    index = {}
    events.keys.sort.each do |id|
      ev = events[id]
      name = ev.respond_to?(:name) ? ev.name : nil
      (index[name] ||= []) << id if name.is_a?(String) && !name.empty?
    end
    index
  end

  def self.targets(map_id, index)
    return [] unless ENABLED
    QuestMarksRules.resolve(results(map_id).values, index, givers: givers?)
  end
end
