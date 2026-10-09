# frozen_string_literal: true

Record::Slice.register_provider :linear do
  start do
    connections = target["services.repos.connection_queries"]
    register "linear.client", Record::Providers::LinearProvider.client(connections, target["http"])
  end
end
