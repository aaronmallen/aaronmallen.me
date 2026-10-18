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
        connections = grouped

        { pickable: pickable(connections), rows: rows(connected(connections), connections) }
      end

      def count
        connections = grouped

        connected(connections).sum { connections.fetch(it.id, [nil]).size }
      end

      private

      def access(connection)
        return :reconnect if connection&.revoked_at

        lapses_at = connection&.lapses_at
        return unless lapses_at
        return :lapsed if lapses_at <= Time.now

        :lapsing if Blog::TimeZone.today(lapses_at) <= Blog::TimeZone.today + settings.attention[:lapsing_days]
      end

      def connected(connections)
        definition_queries.all.select { !it.connectable? || connections.key?(it.id) || unready?(it) }
      end

      def env(definition)
        definition.env.flat_map do |setting, keys|
          values = settings.public_send(setting)
          keys.map { ["#{setting}_#{it}".upcase, !values[it.to_sym].to_s.empty?] }
        end.to_h
      end

      def grouped = connection_queries.all.group_by(&:provider)

      def pickable(connections)
        definition_queries.all.select do |definition|
          (definition.oauth? || check_service.checks?(definition.id)) && !unready?(definition) &&
            (definition.multiple || !connections.key?(definition.id))
        end
      end

      def row(definition, connection, failures, bridgy)
        env = env(definition)
        jobs = definition.jobs.map { { **it, failure: failures[it[:sync]] } }

        Structs::ServiceRow.new(
          key: connection ? connection.id.to_s : definition.id,
          definition:, connection:, env:, jobs:,
          status: status(definition, connection, env, jobs, bridgy),
        )
      end

      def rows(definitions, connections)
        failures = sync_state_queries.failures.group_by { it[:sync] }.transform_values(&:first)
        bridgy = webmention_queries.settings.accept_bridgy

        definitions.flat_map do |definition|
          (connections[definition.id] || [nil]).map { row(definition, it, failures, bridgy) }
        end
      end

      def running(definition, jobs, bridgy)
        return :paused if definition.id == BRIDGY && !bridgy
        return :failing if jobs.any? { it[:failure] }

        :connected
      end

      def status(definition, connection, env, jobs, bridgy)
        return :not_set_up unless env.values.all?

        access(connection) || running(definition, jobs, bridgy)
      end

      def unready?(definition) = definition.oauth? && !definition.credentials? && !env(definition).values.all?
    end
  end
end
