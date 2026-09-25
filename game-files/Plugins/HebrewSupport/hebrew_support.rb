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

  # Only used for text rendering where formatting codes aren't used (like menus)
  def self.visual_reverse(text)
    return text if text.nil? || !text.is_a?(String)
    text = ensure_utf8(text)
    return text unless text.match?(HEBREW_RANGE)

    # Reverse the order of words, but keep numbers and english words LTR
    words = text.split(' ')
    rev_words = words.map do |w|
      if w.match?(/\A[a-zA-Z0-9\-_.,!?]+\z/)
        w # Keep numbers/english LTR
      else
        w.chars.reverse.join
      end
    end
    return rev_words.reverse.join(' ')
  end

  def self.translate_item_field(item, field_type, default_val)
    return default_val if default_val.nil? || !default_val.is_a?(String)
    return default_val unless language == :he

    candidates = [default_val]
    if item.respond_to?(:id) && item.id
      item_id_str = item.id.to_s
      if field_type == :description
        candidates << "#{item_id_str}_DESC"
        candidates << "#{item_id_str}_description"
      end
      candidates << item_id_str
      candidates << item_id_str.upcase
    end

    translated_text = nil
    candidates.each do |cand|
      res = translate(cand)
      if res != cand
        translated_text = res
        break
      end
    end

    translated_text ||= translate(default_val)
    return translated_text
  end
end

# Intercept _MAPINTL for map event dialogue
if defined?(_MAPINTL)
  alias _hebrew_original_MAPINTL _MAPINTL
  def _MAPINTL(mapid, *arg)
    result = _hebrew_original_MAPINTL(mapid, *arg)
    return HebrewText.translate(result)
  end
end

# Intercept _INTL for global text translation
if defined?(_INTL)
  alias _hebrew_original_INTL _INTL
  def _INTL(message, *arg)
    translated = HebrewText.translate(message)
    return _hebrew_original_INTL(translated, *arg)
  end
end

#===============================================================================
# GameData::Item Translation Overrides
#===============================================================================
if defined?(GameData::Item)
  module GameData
    class Item
      unless method_defined?(:_hebrew_original_name)
        alias _hebrew_original_name name
        def name
          val = _hebrew_original_name
          return HebrewText.translate_item_field(self, :name, val)
        end
      end

      unless method_defined?(:_hebrew_original_name_plural)
        alias _hebrew_original_name_plural name_plural
        def name_plural
          val = _hebrew_original_name_plural
          return HebrewText.translate_item_field(self, :name_plural, val)
        end
      end

      unless method_defined?(:_hebrew_original_portion_name)
        alias _hebrew_original_portion_name portion_name
        def portion_name
          val = _hebrew_original_portion_name
          return HebrewText.translate_item_field(self, :portion_name, val)
        end
      end

      unless method_defined?(:_hebrew_original_portion_name_plural)
        alias _hebrew_original_portion_name_plural portion_name_plural
        def portion_name_plural
          val = _hebrew_original_portion_name_plural
          return HebrewText.translate_item_field(self, :portion_name_plural, val)
        end
      end

      unless method_defined?(:_hebrew_original_description)
        alias _hebrew_original_description description
        def description
          val = _hebrew_original_description
          return HebrewText.translate_item_field(self, :description, val)
        end
      end
    end
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
# And flip X coordinates of characters so it animates Right-to-Left perfectly!
if defined?(getFormattedText)
  alias _hebrew_original_getFormattedText getFormattedText
  def getFormattedText(bitmap, xDst, yDst, widthDst, heightDst, text, lineheight = 32,
                       newlineBreaks = true, explicitBreaksOnly = false,
                       collapseAlignments = false)
                       
    is_hebrew = text.is_a?(String) && text.match?(HebrewText::HEBREW_RANGE)
    
    if is_hebrew
      # Ensure right-alignment tag is present
      unless text.match?(/<\/?(al|ac|ar)>/i)
        text = "<ar>#{text}</ar>"
      end
    end
    
    fmtchars = _hebrew_original_getFormattedText(bitmap, xDst, yDst, widthDst, heightDst, text, lineheight,
                                                 newlineBreaks, explicitBreaksOnly, collapseAlignments)
                                                 
    if is_hebrew && fmtchars.is_a?(Array)
      # Group characters by line (Y coordinate)
      lines = {}
      fmtchars.each do |fch|
        next if !fch.is_a?(Array) || fch.length < 5
        y = fch[2]
        lines[y] ||= []
        lines[y] << fch
      end
      
      lines.each do |y, chars_on_line|
        # Only compute bounding box for objects with actual width
        printable_chars = chars_on_line.select { |c| c[3] > 0 }
        next if printable_chars.empty?
        
        min_x = printable_chars.map { |c| c[1] }.min
        max_right = printable_chars.map { |c| c[1] + c[3] }.max
        
        blocks = []
        current_block = []
        is_ltr_block = false
        
        chars_on_line.each do |c|
          char_str = c[0]
          
          is_ltr = false
          if c[5] # Graphic or Icon (e.g. bagPocket8)
            is_ltr = true
          elsif char_str.is_a?(String) && char_str.match?(/\A[a-zA-Z0-9.,!?%\-]+\z/)
            is_ltr = true
          end
          
          if current_block.empty?
            is_ltr_block = is_ltr
            current_block << c
          elsif is_ltr_block == is_ltr
            current_block << c
          else
            blocks << { chars: current_block, is_ltr: is_ltr_block }
            is_ltr_block = is_ltr
            current_block = [c]
          end
        end
        blocks << { chars: current_block, is_ltr: is_ltr_block } unless current_block.empty?
        
        blocks.each do |block|
          bchars = block[:chars]
          # Bounding box of this block
          b_min_x = bchars.map { |c| c[1] }.min
          b_max_x = bchars.map { |c| c[1] + c[3] }.max
          b_width = b_max_x - b_min_x
          
          # Target mirrored starting position
          new_b_min_x = max_right - (b_min_x - min_x) - b_width
          
          if block[:is_ltr]
            # Maintain internal Left-to-Right order (Numbers, English, Graphics)
            bchars.each do |c|
              offset = c[1] - b_min_x
              c[1] = new_b_min_x + offset
            end
          else
            # Reverse internal Right-to-Left order (Hebrew)
            bchars.each do |c|
              old_x = c[1]
              width = c[3]
              c[1] = new_b_min_x + (b_width - (old_x - b_min_x) - width)
            end
          end
        end
      end
    end
    
    return fmtchars
  end
end

# Hook low-level drawing functions to visually reverse Hebrew text in menus
# This ensures Item names like "20 Shekel" render properly in menus
if defined?(pbDrawShadowText)
  alias _hebrew_original_pbDrawShadowText pbDrawShadowText
  def pbDrawShadowText(bitmap, x, y, width, height, string, baseColor, shadowColor = nil, align = 0)
    if string.is_a?(String) && string.match?(HebrewText::HEBREW_RANGE)
      string = HebrewText.visual_reverse(string)
      align = 1 if (align == 0 || align == :left || align == false || align.nil?) && width > 0
    end
    return _hebrew_original_pbDrawShadowText(bitmap, x, y, width, height, string, baseColor, shadowColor, align)
  end
end

if defined?(pbDrawOutlineText)
  alias _hebrew_original_pbDrawOutlineText pbDrawOutlineText
  def pbDrawOutlineText(bitmap, x, y, width, height, string, baseColor, shadowColor = nil, align = 0)
    if string.is_a?(String) && string.match?(HebrewText::HEBREW_RANGE)
      string = HebrewText.visual_reverse(string)
      align = 1 if (align == 0 || align == :left || align == false || align.nil?) && width > 0
    end
    return _hebrew_original_pbDrawOutlineText(bitmap, x, y, width, height, string, baseColor, shadowColor, align)
  end
end

if defined?(pbDrawPlainText)
  alias _hebrew_original_pbDrawPlainText pbDrawPlainText
  def pbDrawPlainText(bitmap, x, y, width, height, string, baseColor, align = 0)
    if string.is_a?(String) && string.match?(HebrewText::HEBREW_RANGE)
      string = HebrewText.visual_reverse(string)
      align = 1 if (align == 0 || align == :left || align == false || align.nil?) && width > 0
    end
    return _hebrew_original_pbDrawPlainText(bitmap, x, y, width, height, string, baseColor, align)
  end
end

# Hook drawTextEx to properly format, right-align and RTL Hebrew in unformatted windows (e.g. Bag item descriptions)
if defined?(drawTextEx)
  alias _hebrew_original_drawTextEx drawTextEx
  def drawTextEx(bitmap, x, y, width, numlines, text, baseColor, shadowColor)
    if text.is_a?(String) && text.match?(HebrewText::HEBREW_RANGE)
      lineheight = 32
      drawFormattedTextEx(bitmap, x, y, width, text, baseColor, shadowColor, lineheight)
    else
      _hebrew_original_drawTextEx(bitmap, x, y, width, numlines, text, baseColor, shadowColor)
    end
  end
end

# Hook pbMessage to replace auto-advancing \wtnp[...] tags with pause \1
# Now that we don't scramble tags, this will cleanly match and replace!
if defined?(pbMessage)
  alias _hebrew_original_pbMessage pbMessage
  def pbMessage(message, commands = nil, cmdIfCancel = 0, skin = nil, defaultCmd = 0, &block)
    if message.is_a?(String)
      # Replace "Wait Then Next Page" with a standard wait-for-input
      message = message.gsub(/\\wtnp\[\d+\]/i, "\\1")
    end
    return _hebrew_original_pbMessage(message, commands, cmdIfCancel, skin, defaultCmd, &block)
  end
end

#===============================================================================
# Hebrew Right-Alignment for Bag Item List
#===============================================================================
if defined?(Window_PokemonBag)
  class Window_PokemonBag < Window_DrawableCommand
    alias _hebrew_original_drawItem drawItem unless method_defined?(:_hebrew_original_drawItem)

    def drawItem(index, _count, rect)
      if HebrewText.language != :he
        return _hebrew_original_drawItem(index, _count, rect)
      end

      textpos = []
      rect = Rect.new(rect.x + 16, rect.y + 16, rect.width - 16, rect.height)
      xRight = rect.x + rect.width - 16
      thispocket = @bag.pockets[@pocket]

      if index == self.itemCount - 1
        textpos.push([_INTL("CLOSE BAG"), xRight, rect.y + 2, :right, self.baseColor, self.shadowColor])
      else
        item = (@filterlist) ? thispocket[@filterlist[@pocket][index]][0] : thispocket[index][0]
        baseColor   = self.baseColor
        shadowColor = self.shadowColor
        if @sorting && index == self.index
          baseColor   = Color.new(224, 0, 0)
          shadowColor = Color.new(248, 144, 144)
        end
        textpos.push(
          [@adapter.getDisplayName(item), xRight, rect.y + 2, :right, baseColor, shadowColor]
        )
        item_data = GameData::Item.get(item)
        qty = (@filterlist) ? thispocket[@filterlist[@pocket][index]][1] : thispocket[index][1]
        show_qty = item_data.show_quantity? || qty > 1
        showing_register_icon = false
        if item_data.is_important?
          if @bag.registered?(item)
            pbDrawImagePositions(
              self.contents,
              [[_INTL("Graphics/UI/Bag/icon_register"), rect.x, rect.y + 8, 0, 0, -1, 24]]
            )
            showing_register_icon = true
          elsif pbCanRegisterItem?(item)
            pbDrawImagePositions(
              self.contents,
              [[_INTL("Graphics/UI/Bag/icon_register"), rect.x, rect.y + 8, 0, 24, -1, 24]]
            )
            showing_register_icon = true
          end
        end
        if show_qty
          qtytext = _ISPRINTF("x{1: 3d}", qty)
          xQty = (showing_register_icon) ? rect.x + 60 : rect.x
          textpos.push([qtytext, xQty, rect.y + 2, :left, baseColor, shadowColor])
        end
      end
      pbDrawTextPositions(self.contents, textpos)
    end
  end
end

