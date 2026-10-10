# frozen_string_literal: true

module Record
  module Remote
    private

    def remote(client, provider = :github)
      return Failure(:not_configured) unless client.configured?

      yield
    rescue Record::RateLimited
      Failure(:rate_limited)
    rescue Record::Error => e
      Failure([:"#{provider}_failed", e.message])
    end
  end
end
