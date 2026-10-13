# frozen_string_literal: true

module Record
  module Remote
    private

    def remote(client, provider = :github)
      return Failure(:not_configured) unless client.configured?

      yield
    rescue GitHub::RateLimited, Linear::RateLimited
      Failure(:rate_limited)
    rescue GitHub::Error, Linear::Error => e
      Failure([:"#{provider}_failed", e.message])
    end
  end
end
