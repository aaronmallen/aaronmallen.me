# frozen_string_literal: true

module Social
  module Operations
    class SearchAccounts < Operation
      LIMIT = 8
      MINIMUM = 2
      RATE_LIMITED = [Social::Bluesky::Client::RateLimited, Social::Mastodon::Client::RateLimited].freeze

      include Deps[networks: "networks.all"]

      def call(network:, query:)
        client = step find_client(network)
        text = query.to_s.strip

        step(text.length < MINIMUM ? Success(Blog::Constants::EMPTY_ARRAY) : search(client, text))
      end

      private

      def find_client(network)
        client = networks[network]

        client&.configured? ? Success(client) : Failure(:unconfigured)
      end

      def search(client, text)
        Success(client.search(text, limit: LIMIT).reject { it.handle.empty? })
      rescue *RATE_LIMITED
        Failure(:rate_limited)
      rescue Social::Error
        Failure(:failed)
      end
    end
  end
end
