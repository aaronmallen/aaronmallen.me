# frozen_string_literal: true

module Decisions
  module Operations
    class EditDecisionOption < Blog::Operation
      FIELDS = %i[title body note].freeze
      OPTION_EDITED = Blog::Types::DecisionEventKind["option_edited"]

      include Deps[
        contract: "contracts.decision_option_contract",
        decision_option_repo: "repos.decision_option_repo",
        decision_repo: "repos.decision_repo",
      ]

      def call(decision_id, id, params)
        fields = step validate(params)

        transaction do
          decision, option = step find(decision_id, id)
          step revise(decision, option, **fields)
        end
      end

      private

      def find(decision_id, id)
        decision = decision_repo.by_id_for_update(decision_id)
        option = decision && decision_option_repo.on_decision(decision_id, id)

        option ? Success([decision, option]) : Failure(:not_found)
      end

      def revise(decision, option, title:, body:, note:)
        return Success(option) if option.title == title && option.body == body

        noted = decision.closed?
        return Failure([:invalid, { note: [Blog::Contract::BLANK] }]) if noted && note.empty?

        saved = decision_option_repo.update(option.id, title:, body:)
        decision_repo.record(decision.id, OPTION_EDITED, option_id: option.id, note: noted ? note : nil)
        Success(saved)
      end

      def validate(params) = validated(contract.call(FIELDS.to_h { [it, params[it]] }))
    end
  end
end
