# frozen_string_literal: true

require "faraday"
require "faraday/follow_redirects"

module Blog
  module Providers
    module HTTPProvider
      class Connections
        MAX_REDIRECTS = 3
        TIMEOUT = 10

        def initialize(host:, site:)
          @host = host
          @site = site
        end

        def call(
          agent: nil, url: nil, headers: Blog::Constants::EMPTY_HASH, open_timeout: nil, params_encoder: nil,
          redirects: MAX_REDIRECTS, timeout: TIMEOUT
        )
          Faraday.new(url:, headers: { "User-Agent" => user_agent(agent) }.merge(headers)) do |faraday|
            faraday.options.open_timeout = open_timeout || timeout
            faraday.options.params_encoder = params_encoder if params_encoder
            faraday.options.timeout = timeout
            yield faraday
            faraday.response(:follow_redirects, limit: redirects) if redirects.positive?
          end
        end

        private

        def user_agent(agent) = "#{[@host, agent].reject { it.to_s.empty? }.join(' ')} (+#{@site})".lstrip
      end

      class << self
        def build(settings)
          site = settings.site[:url].to_s

          Connections.new(host: Types::Normalized::Host.call(site) { Blog::Constants::EMPTY_STRING }, site:)
        end
      end
    end
  end
end
