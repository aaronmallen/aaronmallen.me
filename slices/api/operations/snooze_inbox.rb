# frozen_string_literal: true

module API
  module Operations
    class SnoozeInbox < Blog::Operation
      KINDS = Structs::InboxRow::KINDS.keys.freeze

      include Deps[
        contract: "contracts.clear_inbox_contract",
        snooze_messages: "mail.operations.snooze_messages",
        snooze_tasks: "tasks.operations.snooze_tasks",
        snooze_webmentions: "social.operations.snooze_webmentions",
      ]

      def call(params, now: Time.now)
        fields = step validate(params)
        ends_at = step upcoming_time(params[:snoozed_until], now)
        snoozed = transaction { KINDS.to_h { [it, step(snoozed(it, fields.fetch(it, []), ends_at))] } }

        { **snoozed, snoozed_until: ends_at }
      end

      private

      def snoozed(kind, ids, ends_at)
        found = __send__(:"snooze_#{kind}").call(ids, ends_at)
        found.fmap { ids }.alt_map { |(_, id, reason)| [:record, kind, id, reason] }
      end

      def validate(params) = validated(contract.call(KINDS.to_h { [it, params[it]] }.compact))
    end
  end
end
