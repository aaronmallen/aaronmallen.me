# frozen_string_literal: true

module Contact
  module Operations
    class MarkMessage < Operation
      include Deps[message_mutations: "repos.message_mutations", message_queries: "repos.message_queries"]

      def call(id, status)
        message = step find(id)

        message_mutations.mark(message, status)
      end

      private

      def find(id) = found(message_queries.by_id(id))
    end
  end
end
