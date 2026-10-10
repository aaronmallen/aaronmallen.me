# frozen_string_literal: true

module Contact
  module Operations
    class ActOnMessages < Blog::Operation
      DELETE = Blog::Types::MessageBulkAction["delete"]
      TAG = Blog::Types::MessageBulkAction["tag"]
      UNTAG = Blog::Types::MessageBulkAction["untag"]

      include Deps[
        contract: "contracts.bulk_contract",
        delete_message: "operations.delete_message",
        mark_message: "operations.mark_message",
        message_queries: "repos.message_queries",
        message_tag_mutations: "repos.message_tag_mutations",
      ]

      def call(params)
        fields = step validate(params)
        act = fields[:act]

        each_record(fields[:ids]) { single(act, it, fields[:tag]) }
      end

      private

      def single(act, id, tag)
        case act
          when DELETE then delete_message.call(id)
          when TAG then tagged(id) { message_tag_mutations.add(id, tag) }
          when UNTAG then tagged(id) { message_tag_mutations.remove(id, tag) }
          else mark_message.call(id, act)
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
