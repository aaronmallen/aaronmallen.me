# frozen_string_literal: true

module Issues
  module Remote
    private

    def remote(client, provider = :github)
      return Failure(:not_configured) unless client.configured?

      yield
    rescue Blog::RateLimited
      Failure(:rate_limited)
    rescue Blog::ServiceError => e
      Failure([:"#{provider}_failed", e.message])
    end
  end
end
