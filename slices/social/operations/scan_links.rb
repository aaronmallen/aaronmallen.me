# frozen_string_literal: true

module Social
  module Operations
    class ScanLinks
      OPENER = { ")" => "(", "]" => "[" }.freeze
      PATTERN = %r{(?<![\w@])https?://[^\s<>"]*[^\s<>".,;:!?]}i

      def call(text)
        text = text.to_s
        found = []
        at = 0

        while (match = PATTERN.match(text, at))
          found << link(text, match)
          at = match.end(0)
        end

        found
      end

      def map(text)
        text.to_s.gsub(PATTERN) do |match|
          url = trim(match)

          yield(url) + match.delete_prefix(url)
        end
      end

      private

      def link(text, match)
        url = trim(match[0])
        start = text[0...match.begin(0)].bytesize

        Structs::Link.new(byte_end: start + url.bytesize, byte_start: start, url:)
      end

      def prose_close?(url)
        close = url[-1].to_s
        open = OPENER[close]

        !open.nil? && url.count(close) > url.count(open)
      end

      def trim(url)
        trimmed = url
        trimmed = trimmed.chop while prose_close?(trimmed)
        trimmed
      end
    end
  end
end
