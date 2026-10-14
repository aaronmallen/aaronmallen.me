# frozen_string_literal: true

require "hanami/middleware/assets"

module Blog
  module Extensions
    module Hanami
      module Middleware
        module Assets
          module Extension
            FINGERPRINTED = %r{-[A-Z0-9]{8}(\.[^/]+)?\z}
            IMMUTABLE = "public, max-age=31536000, immutable"

            def call(env)
              path = env[Rack::PATH_INFO]

              super.tap do |status, headers, _body|
                next unless status == 200 && can_serve(path) && FINGERPRINTED.match?(path)

                headers["cache-control"] = IMMUTABLE
              end
            end
          end
        end
      end
    end
  end
end

Hanami::Middleware::Assets.prepend(Blog::Extensions::Hanami::Middleware::Assets::Extension)
