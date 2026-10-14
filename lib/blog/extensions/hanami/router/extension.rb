# frozen_string_literal: true

require "hanami/router"

module Blog
  module Extensions
    module Hanami
      module Router
        module Extension
          private

          def resolve_endpoint(path, *)
            endpoint = super

            lambda do |env|
              env[RequestTimer::ROUTE] = path
              endpoint.call(env)
            end
          end
        end
      end
    end
  end
end

Hanami::Router.prepend(Blog::Extensions::Hanami::Router::Extension)
