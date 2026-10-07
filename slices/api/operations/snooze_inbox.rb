# frozen_string_literal: true

module API
  module Operations
    class SnoozeInbox < Operation
      KINDS = { tasks: "task", messages: "message", webmentions: "webmention" }.freeze

      include Deps[contract: "contracts.clear_inbox_contract", snooze_inbox_row: "operations.snooze_inbox_row"]

      def call(params, now: Time.now)
        fields = step validate(params)

        transaction do
          KINDS.to_h do |kind, row|
            [kind, fields.fetch(kind, []).map { step snoozed(kind, row, it, params[:snoozed_until], now) }]
          end
        end
      end

      private

      def snoozed(kind, row, id, ends_at, now)
        snooze_inbox_row.call(row, id, ends_at, now:).alt_map { it == :not_found ? [:record, kind, id, it] : it }
      end

      def validate(params) = validated(contract.call(KINDS.keys.to_h { [it, params[it]] }.compact))
    end
  end
end
