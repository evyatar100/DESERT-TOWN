# Kusomo TV step trace (TG49): appends to kusomo_trace.log in the game folder, flushed per line.
# Turn TRACE off once the quit-after-video bug is confirmed fixed.
module KusomoTV
  TRACE = true
  TRACE_FILE = "kusomo_trace.log"

  def self.trace(msg)
    return if !TRACE
    trace_session_start if !@trace_started
    write_trace(msg)
  end

  def self.write_trace(msg)
    File.open(TRACE_FILE, "ab") do |f|
      f.write("#{Time.now.strftime('%H:%M:%S.%L')} #{msg}\r\n")
      f.flush
    end
  rescue StandardError
    nil
  end

  # First trace of a run: a header, and an at_exit hook that names whatever ended the process.
  def self.trace_session_start
    @trace_started = true
    full = (Graphics.fullscreen rescue "?")
    map = ($game_map.map_id rescue "?")
    pos = ($game_player ? "#{$game_player.x},#{$game_player.y}" : "?") rescue "?"
    write_trace("=== session: debug=#{$DEBUG.inspect} fullscreen=#{full} map=#{map} at #{pos}")
    at_exit { KusomoTV.trace_exit($!) }
  end

  def self.trace_exit(err)
    if err
      where = (err.backtrace || [])[0, 6].join(" | ")
      text = err.respond_to?(:event_message) ? err.event_message : err.message
      write_trace("at_exit: #{err.class}: #{text.to_s[0, 400].gsub(/\s+/, ' ')} @ #{where}")
    else
      write_trace("at_exit: normal end (no exception)")
    end
  end
end
