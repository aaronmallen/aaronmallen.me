# frozen_string_literal: true

module Blog
  module Contracts
    class SearchQueryContract < Contract
      FIELDS = {
        agent: [:agents, Types::Normalized::ContributorSlug],
        contributor: [:contributors, Types::Normalized::ContributorKind],
        model: [:models, Types::Normalized::ContributorSlug],
        repo: [:repos, Types::Normalized::Repo],
        tag: [:tags, Types::Normalized::Tag],
      }.freeze
      SPACE = " "
      WHITESPACE = /\s+/

      def self.blank(accepted) = accepted.values.to_h { |key, _| [key, []] }

      def self.collect(accepted, matcher, terms)
        terms.each_with_object(blank(accepted)) do |term, found|
          match = matcher.match(term)
          key, normalize = accepted.fetch(match[:field].to_sym)
          found[key] << normalize.call(match[:value]) { it }
        end.transform_values(&:uniq)
      end

      def self.matcher_for(names) = /\A(?<field>#{Regexp.union(names.map(&:to_s))}):(?<value>\S+)\z/

      private_class_method :blank, :collect, :matcher_for

      def self.parse(query, fields)
        accepted = FIELDS.slice(*fields)
        matcher = matcher_for(accepted.keys)
        text = query.strip
        terms, words = text.split(WHITESPACE).partition { matcher.match?(it) }
        return blank(accepted).merge(text:) if terms.empty?

        collect(accepted, matcher, terms).merge(text: words.join(SPACE))
      end

      params do
        optional(:query).value(Types::Text)
        required(:fields).array(:symbol, included_in?: FIELDS.keys)

        after(:rule_applier) do |result|
          SearchQueryContract.parse(Types::Text[result[:query]], result[:fields]) if result.success?
        end
      end
    end
  end
end
