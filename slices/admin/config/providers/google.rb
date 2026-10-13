# frozen_string_literal: true

Admin::Slice.register_provider :google do
  start do
    register "google.auth", Admin::Auth::Google.new(client: Google::Providers::ClientProvider.oauth(target["settings"]))
  end
end
