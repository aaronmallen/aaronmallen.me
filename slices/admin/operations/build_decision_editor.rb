# frozen_string_literal: true

module Admin
  module Operations
    class BuildDecisionEditor
      FIELDS = %i[title problem tags note].freeze
      RECORD = Blog::Types::RecordKind["decision"]

      include Deps[tag_queries: "tags.repos.tag_queries"]

      def call(decision: nil, params: nil, errors: Blog::Constants::EMPTY_HASH)
        values = params ? from_params(params) : from_decision(decision)
        tag_choices = tag_queries.project_choices(RECORD, decision.id) if decision

        { decision:, values:, errors:, tag_choices: }
      end

      private

      def from_decision(decision)
        { title: decision&.title.to_s, problem: decision&.problem.to_s, tags: tags(decision),
          note: Blog::Constants::EMPTY_STRING }
      end

      def from_params(params) = FIELDS.to_h { [it, Blog::Types::Text[params[it]]] }

      def tags(decision) = decision ? Blog::Types::TagField[decision.tags] : Blog::Constants::EMPTY_STRING
    end
  end
end
