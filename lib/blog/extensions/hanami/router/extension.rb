# frozen_string_literal: true

require "blog/extensions"
require "hanami/router"

module Blog
  module Extensions
    module Hanami
      module Router
        module Extension
          Endpoint = Data.define(:route, :endpoint) do
            def call(env)
              env[RequestTimer::ROUTE] = route
              endpoint.call(env)
            end
          end

          private

          def resolve_endpoint(path, *) = Endpoint.new(path, super)
        end
      end
    end
  end
end

Blog::Extensions.apply(
  Hanami::Router,
  Blog::Extensions::Hanami::Router::Extension,
  gem: "hanami-router",
  version: "3.0.0",
  reason: "the router gives no way to read the matched route pattern, which the request timer records",
  upstream: nil,
)
