# frozen_string_literal: true

module Contact
  module Operations
    class ActOnMessages < Blog::Operation
      DELETE = Blog::Types::MessageBulkAction["delete"]
      FIELDS = %i[act ids].freeze

      include Deps[
        contract: "contracts.bulk_contract",
        delete_message: "operations.delete_message",
        mark_message: "operations.mark_message",
      ]

      def call(params)
        fields = step validate(params)
        act = fields[:act]

        transaction do
          fields[:ids].map { |id| step(single(act, id).alt_map { [:record, id, it] }) }
        end
      end

      private

      def form(params) = FIELDS.to_h { [it, params[it]] }

      def single(act, id) = act == DELETE ? delete_message.call(id) : mark_message.call(id, act)

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
