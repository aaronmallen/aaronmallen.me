# auto_register: false
# frozen_string_literal: true

module Admin
  class ConnectOperation < Blog::Operation
    include Deps[
      add_connection: "services.operations.add_connection",
      change_connection: "services.operations.change_connection",
      connection_queries: "services.repos.connection_queries",
    ]

    private

    def save(held, **grant)
      return add_connection.call(provider: self.class::PROVIDER, **grant) if held.nil?

      change_connection.call(held.id, **grant, revoked_at: nil)
      Success(connection_queries.by_id(held.id))
    end
  end
end
