# frozen_string_literal: true

module Blog
  module ContributorTerms
    module_function

    def call(contributor: nil, agent: nil, model: nil)
      { contributors: named(contributor), agents: named(agent), models: named(model) }
    end

    def named(value) = [value.to_s.strip.downcase].reject(&:empty?)
  end
end
