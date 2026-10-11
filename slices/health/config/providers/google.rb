# frozen_string_literal: true

Health::Slice.register_provider :google do
  start do
    register "google.client", Health::Providers::GoogleProvider.client(
      target["settings"], target["services.repos.connection_queries"], target["services.operations.change_connection"],
    )
  end
end
