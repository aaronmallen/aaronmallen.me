# frozen_string_literal: true

module API
  module Operations
    class ClearInbox < Blog::Operation
      KINDS = Contracts::ClearInboxContract::KINDS
      READ = Blog::Types::MessageStatus["read"]

      include Deps[
        change_thread: "mail.operations.change_thread",
        contract: "contracts.clear_inbox_contract",
        mark_tasks_seen: "tasks.operations.mark_tasks_seen",
        mark_webmention_seen: "social.operations.mark_webmention_seen",
        message_queries: "mail.repos.message_queries",
      ]

      def call(params)
        fields = step validate(params)
        ids = KINDS.to_h { [it, fields.fetch(it, [])] }
        step found_messages(ids[:messages])
        each(:messages, ids, local: false)

        transaction do
          { tasks: step(tasks(ids[:tasks])), messages: each(:messages, ids, remote: false),
            webmentions: each(:webmentions, ids) }
        end
      end

      private

      def clear(kind, id, **)
        kind == :messages ? change_thread.call(id, READ, **) : mark_webmention_seen.call(id)
      end

      def cleared(kind, id, **) = clear(kind, id, **).fmap(&:id).alt_map { [:record, kind, id, it] }

      def each(kind, ids, **) = ids.fetch(kind).map { step cleared(kind, it, **) }

      def found_messages(ids)
        gone = ids - message_queries.thread_ids(ids)
        gone.empty? ? Success(ids) : Failure[:record, :messages, gone.first, :not_found]
      end

      def tasks(ids) = mark_tasks_seen.call(ids).alt_map { |(_, id, reason)| [:record, :tasks, id, reason] }

      def validate(params) = validated(contract.call(KINDS.to_h { [it, params[it]] }.compact))
    end
  end
end
