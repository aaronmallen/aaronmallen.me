# frozen_string_literal: true

module Services
  module Operations
    class AddConnection < Operation
      include Deps["repos.connection_mutations", "repos.connection_queries", "repos.definition_queries"]

      def call(provider:, account_id:, host: nil, **columns)
        definition = step known(provider)
        step open_to(definition, host, account_id)

        connection_mutations.add(provider: definition.id, account_id:, host:, **columns)
      rescue ROM::SQL::UniqueConstraintError
        Failure(:taken)
      end

      private

      def known(provider) = found(definition_queries.all.find { it.id == provider.to_s && it.connectable? })

      def open_to(definition, host, account_id)
        return Failure(:taken) if connection_queries.account?(definition.id, host, account_id)
        return Failure(:single) unless definition.multiple || connection_queries.for(definition.id).empty?

        Success(definition)
      end
    end
  end
end
