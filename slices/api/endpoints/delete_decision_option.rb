# frozen_string_literal: true

module API
  module Endpoints
    class DeleteDecisionOption < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Decisions::ID, option_id: Decisions::ID },
        required: %w[id option_id],
      }.freeze

      REPLY = Helpers::Schema.object(
        { id: Helpers::Schema::INTEGER, option_id: Helpers::Schema::INTEGER, deleted: Helpers::Schema::BOOLEAN },
      ).freeze

      include Deps[delete_decision_option: "decisions.operations.delete_decision_option"]

      def handle(id:, option_id:)
        case delete_decision_option.call(id, option_id)
          in Success(*) then Success(id:, option_id:, deleted: true)
          in Failure(:not_found) then not_found(Decisions.missing_option(id, option_id))
          in Failure[:invalid, _] then chosen
          else failed(Helpers::Wording::UNSAVED)
        end
      end

      private

      def chosen
        reason = Helpers::Wording.reason(Decisions::COMPLAINTS, :option_id, "chosen")

        Failure(Structs::Refusal.invalid({ option_id: [reason] }, message: "option_id: #{reason}"))
      end
    end
  end
end
