# frozen_string_literal: true

module Admin
  module Operations
    class ConnectService < Operation
      BLANK = "blank"

      include Deps[
        add_connection: "services.operations.add_connection",
        check_service: "operations.check_service",
        definition_queries: "services.repos.definition_queries",
      ]

      def call(provider, fields)
        definition = step found(definition_queries.find(provider))
        credentials = step filled(definition, fields)
        account = step check_service.call(definition.id, credentials)

        step add_connection.call(provider: definition.id, credentials:, **account)
      end

      private

      def filled(definition, fields)
        credentials = definition.fields.to_h { [it.to_sym, fields[it.to_sym].to_s.strip] }
        blank = credentials.select { |_, value| value.empty? }.transform_values { [BLANK] }

        blank.empty? ? Success(credentials) : Failure[:invalid, blank]
      end
    end
  end
end
