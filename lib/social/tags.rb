# frozen_string_literal: true

module Social
  class Tags
    Tag = Data.define(:byte_end, :byte_start, :tag)

    MAX_LENGTH = 64
    PATTERN = /(?<=\A|[[:space:]])[#＃](?!\u{FE0F})[^[:space:]\u00AD\u2060\u200A-\u200D\u20E2]+/
    TRAILING_PUNCTUATION = /\p{P}+\z/
    WORD = /[^\d\p{P}]/

    def initialize(text)
      @text = text.to_s
    end

    def to_a
      found = []
      at = 0

      while (match = PATTERN.match(@text, at))
        found << tag(match)
        at = match.end(0)
      end

      found.compact
    end

    private

    def tag(match)
      name = match[0][1..].sub(TRAILING_PUNCTUATION, "")
      return if name.length > MAX_LENGTH || !name.match?(WORD)

      start = @text[0...match.begin(0)].bytesize

      Tag.new(byte_end: start + match[0][0].bytesize + name.bytesize, byte_start: start, tag: name)
    end
  end
end
