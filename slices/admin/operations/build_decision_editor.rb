# frozen_string_literal: true

module Admin
  module Operations
    class BuildDecisionEditor
      FIELDS = %i[title problem tags note].freeze
      TAG_SEPARATOR = ", "

      def call(decision: nil, params: nil, errors: Blog::Constants::EMPTY_HASH)
        { decision:, values: params ? from_params(params) : from_decision(decision), errors: }
      end

      private

      def from_decision(decision)
        { title: decision&.title.to_s, problem: decision&.problem.to_s, tags: tags(decision),
          note: Blog::Constants::EMPTY_STRING }
      end

      def from_params(params) = FIELDS.to_h { [it, Blog::Types::Text[params[it]]] }

      def tags(decision) = decision ? decision.tags.map(&:name).join(TAG_SEPARATOR) : Blog::Constants::EMPTY_STRING
    end
  end
end
