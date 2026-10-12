# frozen_string_literal: true

module Mail
  module Operations
    class ActOnMessages < Blog::Operation
      DELETE = Blog::Types::MessageBulkAction["delete"]
      MOVE = Blog::Types::MessageBulkAction["move"]
      TAG = Blog::Types::MessageBulkAction["tag"]
      UNTAG = Blog::Types::MessageBulkAction["untag"]

      include Deps[
        change_thread: "operations.change_thread",
        contract: "contracts.bulk_contract",
        delete_message: "operations.delete_message",
        message_queries: "repos.message_queries",
        message_tag_mutations: "repos.message_tag_mutations",
      ]

      def call(params)
        fields = step validate(params)
        act = fields[:act] == MOVE ? fields[:to] : fields[:act]

        each_record(fields[:ids]) { single(act, it, fields) }
      end

      private

      def single(act, id, fields)
        case act
          when DELETE then delete_message.call(id)
          when TAG then tagged(id) { message_tag_mutations.add(id, fields[:tag]) }
          when UNTAG then tagged(id) { message_tag_mutations.remove(id, fields[:tag]) }
          else change_thread.call(id, act, label: fields[:label])
        end
      end

      def tagged(id)
        return found(nil) unless message_queries.exist?(id)

        yield
        found(message_queries.by_id(id))
      end

      def validate(params) = validated(contract.call(every_field(params)))
    end
  end
end
