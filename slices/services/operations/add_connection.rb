# frozen_string_literal: true

module Services
  module Operations
    class AddConnection < Blog::Operation
      ACCOUNT_INDEX = "service_connections_provider_host_account_id_index"

      include Deps["repos.connection_mutations", "repos.connection_queries", "repos.definition_queries"]

      def call(provider:, account_id:, host: nil, **columns)
        definition = step known(provider)
        step open_to(definition)

        step add(provider: definition.id, account_id:, host:, **columns)
      end

      private

      def add(**columns)
        constrained(connection_mutations, ACCOUNT_INDEX => :taken) do
          Success(transaction { connection_mutations.add(**columns) })
        end
      end

      def known(provider) = found(definition_queries.all.find { it.id == provider.to_s && it.connectable? })

      def open_to(definition)
        return Failure(:single) unless definition.multiple || connection_queries.for(definition.id).empty?

        Success(definition)
      end
    end
  end
end
