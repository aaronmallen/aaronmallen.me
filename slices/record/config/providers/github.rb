# frozen_string_literal: true

Record::Slice.register_provider :github do
  start do
    connection_queries = target["services.repos.connection_queries"]

    register "github.client", Record::Providers::GitHubProvider.client(connection_queries, target["http"])
  end
end
