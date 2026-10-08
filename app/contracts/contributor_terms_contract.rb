# frozen_string_literal: true

module Blog
  module Contracts
    class ContributorTermsContract < Contract
      TERMS = { contributor: :contributors, agent: :agents, model: :models }.freeze

      params do
        TERMS.each_key { optional(it).value(Types::Text) }

        after(:rule_applier) do |result|
          TERMS.to_h { |field, key| [key, [result[field].to_s.strip.downcase].reject(&:empty?)] }
        end
      end
    end
  end
end
