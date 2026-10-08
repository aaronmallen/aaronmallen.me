# frozen_string_literal: true

module Record
  module Operations
    class ParseCommitCredits
      AGENTS = { "Claude" => "claude-code" }.freeze
      CLOSES = /^closes #(\d+)[ \t]*$/i
      SEPARATOR = "-"
      TRAILER = /^co-authored-by:[ \t]*([^<\n]*?)[ \t]*<[^>\n]*>[ \t]*$/i
      UNSLUGGED = /[^a-z0-9]+/

      def call(message)
        {
          agents: message.to_s.scan(TRAILER).filter_map { agent(it.first) }.uniq,
          issues: message.to_s.scan(CLOSES).map { Integer(it.first, 10) }.uniq,
        }
      end

      private

      def agent(name)
        prefix, rest = name.split(nil, 2)
        model = [prefix, rest].join(SEPARATOR).downcase.split(UNSLUGGED).reject(&:empty?).join(SEPARATOR)
        return unless AGENTS.key?(prefix) && rest && model.include?(SEPARATOR)

        { "agent" => AGENTS.fetch(prefix), "model" => model } if Blog::Types::ContributorSlug.valid?(model)
      end
    end
  end
end
