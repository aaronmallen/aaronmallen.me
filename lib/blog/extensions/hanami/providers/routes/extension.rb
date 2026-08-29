# frozen_string_literal: true

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

Hanami::Providers::Routes.prepend(Blog::Extensions::Hanami::Providers::Routes::Extension)
