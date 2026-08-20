#===============================================================================
# Translation System Automated Test Suite
#===============================================================================

module HebrewTranslationTest
  def self.run_all
    passed = 0
    failed = 0
    tests = [
      :test_load_file,
      :test_known_translation,
      :test_missing_key_fallback,
      :test_hebrew_reversal,
      :test_translate_and_reverse,
      :test_english_passthrough,
      :test_nil_and_empty_handling,
      :test_hebrew_right_alignment_detection,
      :test_shontal_translation,
      :test_demo_camp4_translations
    ]

    puts "\n" + "=" * 60
    puts " RUNNING HEBREW TRANSLATION SUITE"
    puts "=" * 60

    tests.each do |test_name|
      begin
        result = send(test_name)
        if result
          puts "  [PASS] #{test_name}"
          passed += 1
        else
          puts "  [FAIL] #{test_name}"
          failed += 1
        end
      rescue => e
        puts "  [ERROR] #{test_name}: #{e.message}"
        failed += 1
      end
    end

    puts "-" * 60
    puts " RESULTS: #{passed} Passed | #{failed} Failed"
    puts "=" * 60 + "\n"
    return failed == 0
  end

  def self.test_load_file
    HebrewText.reload
    translations = HebrewText.translations
    return translations.is_a?(Hash) && !translations.empty?
  end

  def self.test_known_translation
    translated = HebrewText.translate("Looks like this is not ready...")
    return translated == "נראה שזה עדיין לא מוכן..."
  end

  def self.test_missing_key_fallback
    unknown = "This key does not exist in translations.json"
    return HebrewText.translate(unknown) == unknown
  end

  def self.test_hebrew_reversal
    original = "שלום"
    expected = "םולש"
    return HebrewText.reverse_hebrew(original) == expected
  end

  def self.test_translate_and_reverse
    # Translation of "Looks like this is not ready..." reversed
    original = "Looks like this is not ready..."
    hebrew_text = "נראה שזה עדיין לא מוכן..."
    expected_reversed = hebrew_text.chars.reverse.join
    actual = HebrewText.translate_and_reverse(original)
    return actual == expected_reversed
  end

  def self.test_english_passthrough
    english = "Hello 123 World!"
    return HebrewText.reverse_hebrew(english) == english
  end

  def self.test_nil_and_empty_handling
    return HebrewText.translate(nil).nil? &&
           HebrewText.translate("").empty? &&
           HebrewText.reverse_hebrew(nil).nil? &&
           HebrewText.reverse_hebrew("").empty?
  end

  def self.test_hebrew_right_alignment_detection
    hebrew_sample = "שלום"
    english_sample = "Hello"
    is_hebrew_detected = hebrew_sample.match?(HebrewText::HEBREW_RANGE)
    is_english_detected = english_sample.match?(HebrewText::HEBREW_RANGE)
    return is_hebrew_detected && !is_english_detected
  end

  def self.test_shontal_translation
    translated_name = HebrewText.translate("Shontal")
    translated_text = HebrewText.translate("Yesterday Shontal Netz plugged her straightener into the power grid and ran out our supply! She is a sparkling unicorn and refuses to go outside to get electricity powder from the Karahana because there is too much dust and it ruins her facial skin. Save the camp and go get us electricity powder before we have to see Shontal furious with curly hair!")
    return translated_name == "שונטל" && translated_text.include?("אתמול שונטל נץ")
  end

  def self.test_demo_camp4_translations
    t1 = HebrewText.translate("The chairs here have a proportion problem.")
    t2 = HebrewText.translate("A beer? Go to your sit and I'll give you one.")
    t3 = HebrewText.translate("haaaaaaaaa!")
    return t1 == "לכיסאות כאן יש בעיית פרופורציה." &&
           t2 == "בירה? לך למקום שלך ואני אתן לך אחת." &&
           t3 == "האהאהאהאהא!"
  end
end

# Automatically run tests on boot when in Debug mode or standard execution
if defined?(HebrewTranslationTest) && defined?(PluginManager)
  # Execute tests when loaded
  HebrewTranslationTest.run_all
end
