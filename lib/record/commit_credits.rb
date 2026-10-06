# frozen_string_literal: true

module Record
  module CommitCredits
    AGENTS = { "Claude" => "claude-code" }.freeze
    CLOSES = /^closes #(\d+)[ \t]*$/i
    SEPARATOR = "-"
    TRAILER = /^co-authored-by:[ \t]*([^<\n]*?)[ \t]*<[^>\n]*>[ \t]*$/i
    UNSLUGGED = /[^a-z0-9]+/

    module_function

    def agent(name)
      prefix, rest = name.split(nil, 2)
      model = [prefix, rest].join(SEPARATOR).downcase.split(UNSLUGGED).reject(&:empty?).join(SEPARATOR)
      return unless AGENTS.key?(prefix) && rest && model.include?(SEPARATOR)

      { "agent" => AGENTS.fetch(prefix), "model" => model } if Blog::Types::ContributorSlug.valid?(model)
    end

    def agents(message) = message.to_s.scan(TRAILER).filter_map { agent(it.first) }.uniq

    def issues(message) = message.to_s.scan(CLOSES).map { Integer(it.first, 10) }.uniq
  end
end
