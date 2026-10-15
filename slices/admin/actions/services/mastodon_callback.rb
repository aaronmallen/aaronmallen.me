# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class MastodonCallback < ServiceCallback
        NAME = "Mastodon"
        PROVIDER = Blog::Types::ServiceProvider["mastodon"]

        include Deps[connect_mastodon: "operations.connect_mastodon"]

        private

        def connect(started, code)
          connect_mastodon.call(
            host: started.fetch("host"), code:, code_verifier: started.fetch("verifier"), redirect_uri:,
          )
        end
      end
    end
  end
end
