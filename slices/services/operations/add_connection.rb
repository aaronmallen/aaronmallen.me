# frozen_string_literal: true

module Services
  module Operations
    class AddConnection < Operation
      include Deps["repos.connection_mutations", "repos.connection_queries", "repos.definition_queries"]

      def call(provider:, account_id:, **)
        definition = step found(definition_queries.find(provider))
        step room(definition)
        step fresh(definition, account_id, **)

        connection_mutations.add(provider: definition.id, account_id:, **)
      end

      private

      def fresh(definition, account_id, host: nil, **)
        connection_queries.held?(definition.id, account_id, host) ? Failure(:duplicate) : Success(definition)
      end

      def room(definition)
        return Success(definition) if definition.multiple || connection_queries.for(definition.id).empty?

        Failure(:single)
      end
    end
  end
end
