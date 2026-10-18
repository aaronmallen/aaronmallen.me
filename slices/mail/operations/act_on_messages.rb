# frozen_string_literal: true

module Mail
  module Operations
    class ActOnMessages < Blog::Operation
      DELETE = Blog::Types::MessageBulkAction["delete"]
      MOVE = Blog::Types::MessageBulkAction["move"]
      TAG = Blog::Types::MessageBulkAction["tag"]
      UNTAG = Blog::Types::MessageBulkAction["untag"]
      LOCAL_FIRST = [DELETE, Blog::Types::MessageBulkAction["label"], TAG, UNTAG].freeze

      include Deps[
        change_thread: "operations.change_thread",
        contract: "contracts.bulk_contract",
        delete_message: "operations.delete_message",
        google: "google.client",
        message_queries: "repos.message_queries",
        message_tag_mutations: "repos.message_tag_mutations",
      ]

      def call(params)
        fields = step validate(params)
        act = fields[:act] == MOVE ? fields[:to] : fields[:act]

        gmail_first = !LOCAL_FIRST.include?(act)
        told_gmail(act, fields[:ids]) if gmail_first

        each_record(fields[:ids]) { single(act, it, fields, remote: !gmail_first) }
      end

      private

      def single(act, id, fields, remote:)
        case act
          when DELETE then delete_message.call(id)
          when TAG then tagged(id) { message_tag_mutations.add(id, fields[:tag]) }
          when UNTAG then tagged(id) { message_tag_mutations.remove(id, fields[:tag]) }
          else change_thread.call(id, act, label: fields[:label], remote:)
        end
      end

      def tagged(id)
        return found(nil) unless message_queries.exist?(id)

        yield
        found(message_queries.by_id(id))
      end

      def told_gmail(act, ids)
        client = google.loaded
        ids.each { |id| step(change_thread.call(id, act, client:, local: false).alt_map { [:record, id, it] }) }
      end
    end
  end
end
