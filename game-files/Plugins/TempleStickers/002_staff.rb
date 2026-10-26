#===============================================================================
# TempleStickers - staff (moderation) mode. The code lives only in the
# untracked temple_staff.cfg beside Game.rxdata, written by hand:
#   code=<staff code>
#   reward=on|off
# The code is typed on the in-game code keyboard, so it may use only Hebrew
# letters (finals too), a-z, A-Z, space and . , ? ! ' - ׳ ; at most 12
# characters; no digits, no @. No file means no staff mode. Never log the code.
#===============================================================================

module TempleStickers
  module Staff
    @active = false

    def self.path(dir)
      File.join(dir, STAFF_FILE)
    end

    # "key=value" lines; "#" comments; tolerates a BOM and CRLF from Notepad.
    def self.parse(text)
      cfg = {}
      text.to_s.dup.force_encoding("UTF-8").sub(/\A﻿/, "").each_line do |line|
        line = line.strip
        next if line.empty? || line.start_with?("#")
        key, value = line.split("=", 2)
        next if value.nil?
        cfg[key.strip.downcase] = value.strip
      end
      cfg
    end

    def self.read(dir)
      file = path(dir)
      return nil unless File.file?(file)
      parse(File.binread(file))
    rescue StandardError
      nil
    end

    # nil when the code can be typed; else :missing, :too_long or :untypeable.
    def self.code_problem(cfg)
      code = cfg.is_a?(Hash) ? cfg["code"].to_s : ""
      return :missing if code.empty?
      return :too_long if code.length > CODE_MAX
      return :untypeable unless code.chars.all? { |c| Keyboard.allowed_char?(c) }
      nil
    end

    # Names the problem only; the value itself never reaches a log.
    def self.warn_if_untypeable(cfg)
      problem = code_problem(cfg)
      return nil if problem.nil?
      if defined?(echoln)
        echoln "[TempleStickers] #{STAFF_FILE}: code is #{problem}; allowed: letters, space, " \
               ". , ? ! ' - geresh; max #{CODE_MAX}; no digits"
      end
      problem
    end

    def self.matches?(typed, cfg)
      return false unless cfg.is_a?(Hash) && typed.is_a?(String)
      code = cfg["code"]
      return false if code.nil? || code.empty?
      typed.strip == code
    end

    # Default on: only an explicit reward=off turns the Ido visit off.
    def self.reward_on?(cfg)
      return true unless cfg.is_a?(Hash)
      cfg["reward"].to_s.downcase != "off"
    end

    # Rewrites only the reward line; every other line is kept as written.
    def self.with_reward(text, on)
      value = on ? "on" : "off"
      lines = text.to_s.dup.force_encoding("UTF-8").split(/\r?\n/, -1)
      lines.pop if lines.last == ""
      found = false
      lines.map! do |line|
        next line unless line.strip.split("=", 2).first.to_s.strip.downcase == "reward"
        found = true
        "reward=#{value}"
      end
      lines << "reward=#{value}" unless found
      lines.join("\n") + "\n"
    end

    # False when there is no cfg (staff mode does not exist) or the write fails.
    def self.write_reward(dir, on)
      file = path(dir)
      return false unless File.file?(file)
      tmp = file + ".tmp"
      File.binwrite(tmp, with_reward(File.binread(file), on))
      File.rename(tmp, file)
      true
    rescue StandardError
      false
    end

    # Active until the next run starts (003_run clears it); never saved.
    def self.activate
      @active = true
    end

    def self.deactivate
      @active = false
    end

    def self.active?
      @active == true
    end
  end
end
