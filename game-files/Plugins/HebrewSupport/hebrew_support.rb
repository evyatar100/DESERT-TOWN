#===============================================================================
# Hebrew Text, BiDi RTL & Translation Plugin for Pokémon Essentials (v21.1)
#===============================================================================

module SimpleJSONParser
  def self.parse(source)
    return {} if source.nil? || source.strip.empty?
    source = source.dup
    source.force_encoding('UTF-8') if source.respond_to?(:force_encoding)
    tokens = tokenize(source)
    return {} if tokens.empty?
    val, _ = parse_value(tokens, 0)
    val.is_a?(Hash) ? val : {}
  end

  def self.tokenize(str)
    tokens = []
    i = 0
    len = str.length
    while i < len
      case str[i]
      when " ", "\t", "\n", "\r"
        i += 1
      when "{", "}", "[", "]", ":", ","
        tokens << str[i]
        i += 1
      when '"'
        j = i + 1
        while j < len
          if str[j] == '\\'
            j += 2
          elsif str[j] == '"'
            break
          else
            j += 1
          end
        end
        tokens << str[i..j]
        i = j + 1
      else
        j = i
        while j < len && ![" ", "\t", "\n", "\r", "{", "}", "[", "]", ":", ","].include?(str[j])
          j += 1
        end
        tokens << str[i...j]
        i = j
      end
    end
    tokens
  end

  def self.parse_value(tokens, pos)
    token = tokens[pos]
    return [nil, pos + 1] if token.nil?

    if token == "{"
      parse_object(tokens, pos)
    elsif token == "["
      parse_array(tokens, pos)
    elsif token.start_with?('"')
      [parse_string(token), pos + 1]
    elsif token == "true"
      [true, pos + 1]
    elsif token == "false"
      [false, pos + 1]
    elsif token == "null"
      [nil, pos + 1]
    elsif token =~ /\A-?\d+(\.\d+)?([eE][+-]?\d+)?\z/
      val = token.include?('.') ? token.to_f : token.to_i
      [val, pos + 1]
    else
      [token, pos + 1]
    end
  end

  def self.parse_object(tokens, pos)
    obj = {}
    pos += 1
    return [obj, pos + 1] if tokens[pos] == "}"

    loop do
      break if pos >= tokens.length || tokens[pos] == "}"
      key_token = tokens[pos]
      key = parse_string(key_token)
      pos += 1
      pos += 1 if tokens[pos] == ":"
      val, pos = parse_value(tokens, pos)
      obj[key] = val if key

      if tokens[pos] == ","
        pos += 1
      elsif tokens[pos] == "}"
        pos += 1
        break
      else
        break
      end
    end
    [obj, pos]
  end

  def self.parse_array(tokens, pos)
    arr = []
    pos += 1
    return [arr, pos + 1] if tokens[pos] == "]"

    loop do
      break if pos >= tokens.length || tokens[pos] == "]"
      val, pos = parse_value(tokens, pos)
      arr << val

      if tokens[pos] == ","
        pos += 1
      elsif tokens[pos] == "]"
        pos += 1
        break
      else
        break
      end
    end
    [arr, pos]
  end

  def self.parse_string(token)
    return "" if token.nil? || token.length <= 2
    raw = token[1..-2]
    raw = raw.gsub(/\\(["\\\/bfnrt])/) do
      case $1
      when '"', '\\', '/' then $1
      when 'b' then "\b"
      when 'f' then "\f"
      when 'n' then "\n"
      when 'r' then "\r"
      when 't' then "\t"
      else $1
      end
    end
    raw = raw.gsub(/\\u([0-9a-fA-F]{4})/) { [$1.hex].pack("U") }
    raw
  end
end

module HebrewText
  HEBREW_RANGE = /[\u0590-\u05FF]/
  PRIMARY_FILE = "PBS/translations.json"
  FALLBACK_FILE = "Data/translations.json"

  @translations = nil
  @language = :he

  def self.language
    @language ||= :he
  end

  def self.language=(lang)
    @language = lang.to_sym
  end

  def self.load_translations
    @translations = {}
    path = nil
    if File.exist?(PRIMARY_FILE)
      path = PRIMARY_FILE
    elsif File.exist?(FALLBACK_FILE)
      path = FALLBACK_FILE
    end

    if path
      begin
        content = File.read(path, encoding: 'utf-8')
        data = SimpleJSONParser.parse(content)
        raw_entries = nil
        if data.is_a?(Hash) && data.key?("translations")
          raw_entries = data["translations"]
        elsif data.is_a?(Hash)
          raw_entries = data
        end

        if raw_entries.is_a?(Array)
          raw_entries.each do |item|
            next unless item.is_a?(Hash) && item["key"]
            k = item["key"]
            @translations[k] = item
            if item["en"] && !@translations.key?(item["en"])
              @translations[item["en"]] = item
            end
          end
        elsif raw_entries.is_a?(Hash)
          raw_entries.each do |k, v|
            if v.is_a?(Hash)
              @translations[k] = v
              if v["en"] && !@translations.key?(v["en"])
                @translations[v["en"]] = v
              end
            else
              @translations[k] = v
            end
          end
        end

        echoln "[HebrewSupport] Loaded #{@translations.size} translation entries from #{path}" if defined?(echoln)
      rescue => e
        echoln "[HebrewSupport] Failed to load translations from #{path}: #{e.message}" if defined?(echoln)
      end
    else
      echoln "[HebrewSupport] Translation file not found at #{PRIMARY_FILE} or #{FALLBACK_FILE}" if defined?(echoln)
    end
    @translations
  end

  def self.translations
    @translations ||= load_translations
  end

  def self.reload
    load_translations
  end

  def self.ensure_utf8(text)
    return text if text.nil? || !text.is_a?(String)
    if text.bytes.any? { |b| b >= 0xE0 && b <= 0xFA } && !text.match?(HEBREW_RANGE)
      begin
        conv = text.dup.force_encoding('Windows-1255').encode('UTF-8')
        return conv if conv.match?(HEBREW_RANGE)
      rescue
      end
    end
    text = text.dup if text.frozen?
    text.force_encoding('UTF-8') if text.respond_to?(:force_encoding) && text.encoding.name != 'UTF-8'
    return text
  end

  def self.translate(text)
    return text if text.nil? || !text.is_a?(String)
    text = ensure_utf8(text)
    stripped = text.strip
    lang_key = language.to_s

    entry = translations[stripped] || translations[stripped.gsub(/\s+/, ' ')]

    if entry.is_a?(Hash)
      val = entry[lang_key] || entry["he"] || entry["en"]
      return val.is_a?(String) ? val : text
    elsif entry.is_a?(String)
      return (language == :he) ? entry : text
    end

    return text
  end

  def self.wrap_hebrew_line(text, max_len = 38)
    words = text.split(' ')
    lines = []
    current_line = []
    current_len = 0
    words.each do |word|
      word_len = word.length
      space_len = current_line.empty? ? 0 : 1
      if current_len + word_len + space_len <= max_len
        current_line << word
        current_len += word_len + space_len
      else
        lines << current_line.join(' ') unless current_line.empty?
        current_line = [word]
        current_len = word_len
      end
    end
    lines << current_line.join(' ') unless current_line.empty?
    lines
  end

  def self.reverse_hebrew(text)
    return text if text.nil? || !text.is_a?(String)
    text = ensure_utf8(text)
    return text unless text.match?(HEBREW_RANGE)

    paragraphs = text.split("\n")
    result_paragraphs = []

    paragraphs.each do |p|
      if p.strip.empty?
        result_paragraphs << p
        next
      end
      wrapped_lines = (p.length > 38) ? wrap_hebrew_line(p, 38) : [p]
      reversed_lines = wrapped_lines.map { |line| line.chars.reverse.join }
      result_paragraphs << reversed_lines.join("\n")
    end

    result_paragraphs.join("\n")
  end

  def self.translate_and_reverse(text)
    return text if text.nil? || !text.is_a?(String)
    translated = translate(text)
    return (language == :he) ? reverse_hebrew(translated) : translated
  end
end

# Intercept _MAPINTL for map event dialogue
if defined?(_MAPINTL)
  alias _hebrew_original_MAPINTL _MAPINTL
  def _MAPINTL(mapid, *arg)
    result = _hebrew_original_MAPINTL(mapid, *arg)
    return HebrewText.translate_and_reverse(result)
  end
end

# Intercept _INTL for global text translation
if defined?(_INTL)
  alias _hebrew_original_INTL _INTL
  def _INTL(message, *arg)
    translated = HebrewText.translate_and_reverse(message)
    return _hebrew_original_INTL(translated, *arg)
  end
end

# Set active font configuration
if defined?(MessageConfig)
  MessageConfig::FONT_NAME        = "Handjet"
  MessageConfig::SMALL_FONT_NAME  = "Handjet"
  MessageConfig::NARROW_FONT_NAME = "Handjet"
end

if defined?(Font) && Font.respond_to?(:default_name=)
  Font.default_name = ["Handjet", "David", "Arial", "Power Green"]
end

#===============================================================================
# Hebrew Text Right Alignment Overrides
#===============================================================================

# Enforce Right-Alignment on Hebrew Formatted Text (Dialogue & Message Windows)
if defined?(getFormattedText)
  alias _hebrew_original_getFormattedText getFormattedText
  def getFormattedText(bitmap, xDst, yDst, widthDst, heightDst, text, lineheight = 32,
                       newlineBreaks = true, explicitBreaksOnly = false,
                       collapseAlignments = false)
    if text.is_a?(String) && text.match?(HebrewText::HEBREW_RANGE)
      unless text.match?(/<\/?(al|ac|ar)>/i)
        text = "<ar>#{text}</ar>"
      end
    end
    return _hebrew_original_getFormattedText(bitmap, xDst, yDst, widthDst, heightDst, text, lineheight,
                                            newlineBreaks, explicitBreaksOnly, collapseAlignments)
  end
end

# Enforce Right-Alignment on Hebrew Simple/Shadow/Outline Text (Menus & Commands)
if defined?(pbDrawShadowText)
  alias _hebrew_original_pbDrawShadowText pbDrawShadowText
  def pbDrawShadowText(bitmap, x, y, width, height, string, baseColor, shadowColor = nil, align = 0)
    if (align == 0 || align == :left || align == false || align.nil?) && string.is_a?(String) && string.match?(HebrewText::HEBREW_RANGE) && width > 0
      align = 1
    end
    return _hebrew_original_pbDrawShadowText(bitmap, x, y, width, height, string, baseColor, shadowColor, align)
  end
end

if defined?(pbDrawOutlineText)
  alias _hebrew_original_pbDrawOutlineText pbDrawOutlineText
  def pbDrawOutlineText(bitmap, x, y, width, height, string, baseColor, shadowColor = nil, align = 0)
    if (align == 0 || align == :left || align == false || align.nil?) && string.is_a?(String) && string.match?(HebrewText::HEBREW_RANGE) && width > 0
      align = 1
    end
    return _hebrew_original_pbDrawOutlineText(bitmap, x, y, width, height, string, baseColor, shadowColor, align)
  end
end

if defined?(pbDrawPlainText)
  alias _hebrew_original_pbDrawPlainText pbDrawPlainText
  def pbDrawPlainText(bitmap, x, y, width, height, string, baseColor, align = 0)
    if (align == 0 || align == :left || align == false || align.nil?) && string.is_a?(String) && string.match?(HebrewText::HEBREW_RANGE) && width > 0
      align = 1
    end
    return _hebrew_original_pbDrawPlainText(bitmap, x, y, width, height, string, baseColor, align)
  end
end

#===============================================================================
# RTL Text Animation for Hebrew Dialogue (Window_AdvancedTextPokemon)
#===============================================================================

class Window_AdvancedTextPokemon
  alias _hebrew_setText setText
  def setText(value)
    _hebrew_setText(value)
    if self.letterbyletter && @text && @text.match?(HebrewText::HEBREW_RANGE)
      @rtl_order_map = pbGetRTLOrderMap(@fmtchars)
    else
      @rtl_order_map = nil
    end
  end

  alias _hebrew_letterbyletter_setter letterbyletter=
  def letterbyletter=(value)
    _hebrew_letterbyletter_setter(value)
    if value && @text && @text.match?(HebrewText::HEBREW_RANGE)
      @rtl_order_map = pbGetRTLOrderMap(@fmtchars)
    end
  end

  def pbGetRTLOrderMap(fmtchars)
    return nil if fmtchars.nil? || fmtchars.empty?
    map = []
    i = 0
    len = fmtchars.length
    while i < len
      line_start = i
      line_y = fmtchars[i][2]
      while i < len && fmtchars[i][2] == line_y && fmtchars[i][0] != "\n" && fmtchars[i][0] != "\1"
        i += 1
      end
      line_indices = (line_start...i).to_a.sort_by { |idx| [-fmtchars[idx][1], idx] }
      map.concat(line_indices)
      if i < len && (fmtchars[i][0] == "\n" || fmtchars[i][0] == "\1")
        map.push(i)
        i += 1
      end
    end
    return map
  end

  alias _hebrew_refresh refresh
  def refresh
    if @rtl_order_map && self.letterbyletter
      refresh_rtl
    else
      _hebrew_refresh
    end
  end

  def refresh_rtl
    oldcontents = self.contents
    self.contents = pbDoEnsureBitmap(oldcontents, @bitmapwidth, @bitmapheight)
    self.oy       = @scrollY
    numchars = @numtextchars
    numchars = [@curchar, @numtextchars].min if self.letterbyletter
    return if busy? && @drawncurchar == @curchar && !@scroll_timer_start
    if !self.letterbyletter || !oldcontents.equal?(self.contents)
      @drawncurchar = -1
      @needclear    = true
    end
    if @needclear
      self.contents.font = @oldfont if @oldfont
      self.contents.clear
      @needclear = false
    end
    if @nodraw
      @nodraw = false
      return
    end
    maxX = self.width - self.borderX
    maxY = self.height - self.borderY
    (@drawncurchar + 1..numchars).each do |i|
      next if i >= @fmtchars.length
      target_idx = (@rtl_order_map && i < @rtl_order_map.length) ? @rtl_order_map[i] : i
      next if target_idx.nil? || target_idx >= @fmtchars.length
      if !self.letterbyletter
        next if @fmtchars[target_idx][1] >= maxX
        next if @fmtchars[target_idx][2] >= maxY
      end
      drawSingleFormattedChar(self.contents, @fmtchars[target_idx])
      @lastDrawnChar = target_idx
    end
    self.contents.font = @oldfont if !self.letterbyletter && @oldfont
    if numchars > 0 && numchars != @numtextchars
      target_idx = (@rtl_order_map && (numchars - 1) < @rtl_order_map.length) ? @rtl_order_map[numchars - 1] : (numchars - 1)
      fch = @fmtchars[target_idx] if target_idx && target_idx < @fmtchars.length
      if fch
        rcdst = Rect.new(fch[1], fch[2], fch[3], fch[4])
        if @textchars[numchars] == "\1"
          @endOfText = rcdst
          allocPause
          moveCursor
        else
          @endOfText = Rect.new(rcdst.x + rcdst.width, rcdst.y, 8, 1)
        end
      end
    end
    @drawncurchar = @curchar
  end
end

