# frozen_string_literal: true

module LinkedIn
  class Client
    LIMIT = 3000
    PROVIDER = Blog::Types::ServiceProvider["linkedin"]

    def initialize(auth:)
      @auth = auth
    end

    def configured? = @auth.configured? && !services["repos.connection_queries"].for(PROVIDER).empty?

    def count(text) = text.to_s.grapheme_clusters.size

    def inspect = "#<#{self.class.name} configured=#{configured?}>"

    def limit = LIMIT

    def max_bytes = nil

    def reserved_per_url = nil

    def within_limit?(text) = count(text) <= LIMIT

    private

    def services = Hanami.app.slices[:services]
  end
end
