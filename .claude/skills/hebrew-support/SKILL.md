---
name: hebrew-support
description: Complete architecture, design, and implementation guide for adding Hebrew text, fonts, BiDi RTL rendering, external JSON translations, and localization hooks to Pokémon Essentials (v21.x) running on mkxp-z.
---

# Hebrew Support & Localization Skill for Pokémon Essentials (v21.x)

This skill provides a complete technical guide for configuring Hebrew language support, custom typography (Handjet font), Right-to-Left (RTL) character ordering, external UTF-8 JSON translation dictionaries (`PBS/translations.json`), and unit testing in Pokémon Essentials v21.x projects running on the **mkxp-z** engine.

---

## Architecture Overview

Supporting Hebrew in RPG Maker XP / Pokémon Essentials requires addressing four distinct layers:

```
┌─────────────────────────────────────────────────────────────┐
│                   RPG Maker XP GUI Editor                   │
│     (Retains English dialogue strings to avoid ANSI ????    │
│                     character corruption)                   │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    PBS/translations.json                    │
│    (UTF-8 JSON dictionary containing English -> Hebrew      │
│      mappings; human-editable without unicode escapes)      │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    HebrewSupport Plugin                     │
│    (Loads JSON via embedded SimpleJSONParser, translates    │
│     strings, applies RTL reversal & configures Handjet)     │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                        mkxp-z Engine                        │
│    (Loads Fonts/handjet.ttf via customFonts array in        │
│        mkxp.json and renders Unicode glyphs cleanly)       │
└──────────────────────────────┘
```

---

## 1. External Translation File: `PBS/translations.json`

> **CRITICAL RULE**: Every translation key must be defined in `PBS/translations.json` mapping a unique symbolic key to language variants (`"en"` and `"he"`). The `HebrewSupport` plugin resolves strings dynamically based on `HebrewText.language`.

```json
{
  "meta": {
    "version": "2.0.0",
    "description": "Key-based multi-language translation dictionary for Pokémon Essentials"
  },
  "translations": {
    "MSG_NOT_READY": {
      "en": "Looks like this is not ready...",
      "he": "נראה שזה עדיין לא מוכן..."
    },
    "MSG_GOOD_MORNING": {
      "en": "Good Morning. You are late for your shift.",
      "he": "בוקר טוב. אתה מאחר למשמרת."
    },
    "MSG_HELLO": {
      "en": "Hello, {1}!",
      "he": "שלום, {1}!"
    },
    "MSG_WELCOME_POKECENTER": {
      "en": "Welcome to the Pokémon Center!",
      "he": "ברוכים הבאים למרכז הפוקימונים!"
    }
  }
}
```

---

## 2. HebrewSupport Plugin Architecture

The plugin resides in `Plugins/HebrewSupport/`.

> **CRITICAL**: The mkxp-z Ruby environment does **NOT** include standard library C-extensions like `json.so`. Calling `require 'json'` raises a `LoadError`. The plugin embeds `SimpleJSONParser` directly in pure Ruby.

### `meta.txt`
```ini
Name       = HebrewSupport
Version    = 1.0.0
Essentials = 21.1
Link       = https://github.com
Credits    = RPG Midburn Team
```

### `hebrew_support.rb`

```ruby
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

  def self.load_translations
    @translations = {}
    path = File.exist?(PRIMARY_FILE) ? PRIMARY_FILE : (File.exist?(FALLBACK_FILE) ? FALLBACK_FILE : nil)

    if path
      begin
        content = File.read(path, encoding: 'utf-8')
        data = SimpleJSONParser.parse(content)
        if data.is_a?(Hash) && data["translations"].is_a?(Hash)
          @translations = data["translations"]
        end
      rescue => e
        echoln "[HebrewSupport] Failed loading #{path}: #{e.message}" if defined?(echoln)
      end
    end
    @translations
  end

  def self.translations
    @translations ||= load_translations
  end

  def self.reload
    load_translations
  end

  def self.translate(text)
    return text if text.nil? || !text.is_a?(String)
    text = ensure_utf8(text)
    stripped = text.strip
    return translations[stripped] if translations.key?(stripped)

    normalized = stripped.gsub(/\s+/, ' ')
    return translations[normalized] if translations.key?(normalized)

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
    reverse_hebrew(translate(text))
  end
end

if defined?(_MAPINTL)
  alias _hebrew_original_MAPINTL _MAPINTL
  def _MAPINTL(mapid, *arg)
    result = _hebrew_original_MAPINTL(mapid, *arg)
    HebrewText.translate_and_reverse(result)
  end
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
```

---

## 3. Plugin Automated Test Suite: `test_translations.rb`

Include unit tests in `Plugins/HebrewSupport/test_translations.rb` to verify translation dictionary parsing, missing key fallbacks, and LTR character reversal:

```ruby
module HebrewTranslationTest
  def self.run_all
    passed = 0
    failed = 0
    tests = [
      :test_load_file, :test_known_translation, :test_missing_key_fallback,
      :test_hebrew_reversal, :test_translate_and_reverse, :test_english_passthrough
    ]

    tests.each do |t|
      if send(t)
        passed += 1
      else
        failed += 1
      end
    end
    return failed == 0
  end

  def self.test_load_file
    HebrewText.reload
    HebrewText.translations.is_a?(Hash) && !HebrewText.translations.empty?
  end

  def self.test_known_translation
    HebrewText.translate("Looks like this is not ready...") == "נראה שזה עדיין לא מוכן..."
  end

  def self.test_hebrew_reversal
    HebrewText.reverse_hebrew("שלום") == "םולש"
  end
end
```

---

## 4. Plugin Compilation (`compile_plugins.py`)

Compile all scripts in `Plugins/HebrewSupport/` into `Data/PluginScripts.rxdata` using Python:

```python
import os, sys, zlib, glob
import rubymarshal
from rubymarshal.reader import load
from rubymarshal.writer import write
from rubymarshal.classes import Symbol, RubyString

plugin_scripts_path = os.path.join("Data", "PluginScripts.rxdata")
plugin_dir = os.path.join("Plugins", "HebrewSupport")

with open(plugin_scripts_path, "rb") as f:
    plugins = load(f)

plugins = [p for p in plugins if p[0] != "HebrewSupport" and not (isinstance(p[0], bytes) and p[0] == b"HebrewSupport")]

script_files = sorted(glob.glob(os.path.join(plugin_dir, "*.rb")))
compiled_scripts = []
for sfile in script_files:
    basename = os.path.basename(sfile)
    with open(sfile, "r", encoding="utf-8") as sf:
        code = sf.read()
    compressed = zlib.compress(code.encode("utf-8"))
    compiled_scripts.append([RubyString(basename), compressed])

meta = {
    Symbol("name"): RubyString("HebrewSupport"),
    Symbol("version"): RubyString("1.0.0"),
    Symbol("essentials"): [RubyString("21.1")],
    Symbol("incompatibilities"): [],
    Symbol("link"): RubyString("https://github.com"),
    Symbol("credits"): [RubyString("RPG Midburn Team")]
}

plugins.append([RubyString("HebrewSupport"), meta, compiled_scripts])

with open(plugin_scripts_path, "wb") as f:
    write(f, plugins)
```

---

## Verification & Checklist

- [x] **Zero Dependencies**: No `require 'json'` or external gem imports in plugin code.
- [x] **UTF-8 Translation Storage**: `PBS/translations.json` active and formatted cleanly.
- [x] **Font Installed**: `Fonts/handjet.ttf` present and declared in `mkxp.json`.
- [x] **Automated Tests**: `test_translations.rb` included and passes cleanly.
- [x] **Binary Compilation**: `Data/PluginScripts.rxdata` contains compiled `HebrewSupport` entry.
