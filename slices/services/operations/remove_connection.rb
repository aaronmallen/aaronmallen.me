# frozen_string_literal: true

module Services
  module Operations
    class RemoveConnection < Operation
      include Deps["repos.connection_mutations", "repos.connection_queries"]

      def call(id)
        connection = step found(connection_queries.by_id(id))
        connection_mutations.delete(id)
        connection
      end
    end
  end
end
