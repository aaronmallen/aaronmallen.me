# frozen_string_literal: true

Google::Slice.register_provider :google do
  start do
    register "google.client", Google::Providers::ClientProvider.client(
      target["settings"], target["services.repos.connection_queries"], target["services.operations.change_connection"],
    )
  end
end
