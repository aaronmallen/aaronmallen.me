# frozen_string_literal: true

module Social
  module Operations
    class ScanTags
      MAX_LENGTH = 64
      PATTERN = /(?<=\A|[[:space:]])[#＃](?!\u{FE0F})[^[:space:]­⁠ -‍⃢]+/
      TRAILING_PUNCTUATION = /\p{P}+\z/
      WORD = /[^\d\p{P}]/

      def call(text)
        text = text.to_s
        found = []
        at = 0

        while (match = PATTERN.match(text, at))
          found << tag(text, match)
          at = match.end(0)
        end

        found.compact
      end

      private

      def tag(text, match)
        name = match[0][1..].sub(TRAILING_PUNCTUATION, "")
        return if name.length > MAX_LENGTH || !name.match?(WORD)

        start = text[0...match.begin(0)].bytesize

        Structs::Tag.new(byte_end: start + match[0][0].bytesize + name.bytesize, byte_start: start, tag: name)
      end
    end
  end
end
