# frozen_string_literal: true

module API
  module Endpoints
    class EditDecisionOption < DecisionEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Decisions::ID,
          option_id: Decisions::ID,
          title: { type: "string" },
          body: { type: "string", description: "the option, in Markdown" },
          note: Decisions::NOTE,
        },
        required: %w[id option_id],
      }.freeze

      REPLY = Serializers::DecisionOption.reference

      include Deps[edit_decision_option: "decisions.operations.edit_decision_option"]

      def handle(id:, option_id:, **fields)
        option = decision_queries.by_id(id)&.options&.find { it.id == option_id }
        return not_found(Decisions.missing_option(id, option_id)) if option.nil?

        result = edit_decision_option.call(id, option_id, { title: option.title, body: option.body }.merge(fields))
        saved(result, id, option_id)
      end

      private

      def saved(result, id, option_id)
        case result
        in Success(option) then Success(serialized(Serializers::DecisionOption, option))
        in Failure(:not_found) then not_found(Decisions.missing_option(id, option_id))
        else settled(result, id)
        end
      end
    end
  end
end
