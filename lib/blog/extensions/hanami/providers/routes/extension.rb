# frozen_string_literal: true

require "blog/extensions"
require "hanami/providers/routes"

module Blog
  module Extensions
    module Hanami
      module Providers
        module Routes
          module Extension
            def start
              return super if slice.app?

              register(:routes) { slice.app["routes"] }
            end
          end
        end
      end
    end
  end
end

Blog::Extensions.apply(
  Hanami::Providers::Routes,
  Blog::Extensions::Hanami::Providers::Routes::Extension,
  gem: "hanami",
  version: "3.0.2",
  reason: "a slice gets a routes helper for its own router, not the app's (ADR 0004)",
  upstream: nil,
)
