# frozen_string_literal: true

module API
  module Operations
    class ClearInbox < Operation
      KINDS = Contracts::ClearInboxContract::KINDS
      READ = Blog::Types::MessageStatus["read"]

      include Deps[
        contract: "contracts.clear_inbox_contract",
        mark_message: "contact.operations.mark_message",
        mark_task_seen: "tasks.operations.mark_task_seen",
        mark_webmention_seen: "social.operations.mark_webmention_seen",
      ]

      def call(params)
        fields = step validate(params)

        transaction do
          KINDS.to_h { |kind| [kind, fields.fetch(kind, []).map { step cleared(kind, it) }] }
        end
      end

      private

      def clear(kind, id)
        case kind
        when :tasks then mark_task_seen.call(id)
        when :messages then mark_message.call(id, READ)
        else mark_webmention_seen.call(id)
        end
      end

      def cleared(kind, id) = clear(kind, id).alt_map { [:record, kind, id, it] }

      def validate(params) = validated(contract.call(KINDS.to_h { [it, params[it]] }.compact))
    end
  end
end
