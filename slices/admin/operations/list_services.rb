# frozen_string_literal: true

module Admin
  module Operations
    class ListServices
      BRIDGY = "bridgy"

      include Deps[
        "settings",
        check_service: "operations.check_service",
        connection_queries: "services.repos.connection_queries",
        definition_queries: "services.repos.definition_queries",
        sync_state_queries: "record.repos.sync_state_queries",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def call
        connections = connection_queries.all.group_by(&:provider)
        connected = definition_queries.all.select { !it.connectable? || connections.key?(it.id) }

        { pickable: pickable(connections), rows: rows(connected, connections) }
      end

      private

      def env(definition)
        definition.env.flat_map do |setting, keys|
          values = settings.public_send(setting)
          keys.map { ["#{setting}_#{it}".upcase, !values[it.to_sym].to_s.empty?] }
        end.to_h
      end

      def pickable(connections)
        definition_queries.all.select do |definition|
          (definition.oauth? || check_service.checks?(definition.id)) &&
            (definition.multiple || !connections.key?(definition.id))
        end
      end

      def row(definition, connection, failures, bridgy)
        env = env(definition)
        jobs = definition.jobs.map { { **it, failure: failures[it[:sync]] } }

        Structs::ServiceRow.new(
          key: connection ? connection.id.to_s : definition.id,
          definition:, connection:, env:, jobs:,
          status: status(definition, env, jobs, bridgy),
        )
      end

      def rows(definitions, connections)
        failures = sync_state_queries.failures.group_by { it[:sync] }.transform_values(&:first)
        bridgy = webmention_queries.settings.accept_bridgy

        definitions.flat_map do |definition|
          (connections[definition.id] || [nil]).map { row(definition, it, failures, bridgy) }
        end
      end

      def status(definition, env, jobs, bridgy)
        return :not_set_up unless env.values.all?
        return :paused if definition.id == BRIDGY && !bridgy
        return :failing if jobs.any? { it[:failure] }

        :connected
      end
    end
  end
end
