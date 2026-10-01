# frozen_string_literal: true

module Social
  class Links
    Link = Data.define(:byte_end, :byte_start, :url)

    OPENER = { ")" => "(", "]" => "[" }.freeze
    PATTERN = %r{(?<![\w@])https?://[^\s<>"]*[^\s<>".,;:!?]}i

    def self.prose_close?(url)
      close = url[-1].to_s
      open = OPENER[close]

      !open.nil? && url.count(close) > url.count(open)
    end
    private_class_method :prose_close?

    def self.trim(url)
      trimmed = url
      trimmed = trimmed.chop while prose_close?(trimmed)
      trimmed
    end

    def initialize(text)
      @text = text.to_s
    end

    def map
      @text.gsub(PATTERN) do |match|
        url = self.class.trim(match)

        yield(url) + match.delete_prefix(url)
      end
    end

    def to_a
      found = []
      at = 0

      while (match = PATTERN.match(@text, at))
        found << link(match)
        at = match.end(0)
      end

      found
    end

    private

    def link(match)
      url = self.class.trim(match[0])
      start = @text[0...match.begin(0)].bytesize

      Link.new(byte_end: start + url.bytesize, byte_start: start, url:)
    end
  end
end
