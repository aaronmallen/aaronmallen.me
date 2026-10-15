# frozen_string_literal: true

require "blog/extensions"
require "dry/logger/filter"

module Blog
  module Extensions
    module Dry
      module Logger
        module Filter
          module Extension
            private

            def _key_paths?(value) = value.is_a?(Hash)
          end
        end
      end
    end
  end
end

Blog::Extensions.apply(
  Dry::Logger::Filter,
  Blog::Extensions::Dry::Logger::Filter::Extension,
  gem: "dry-logger",
  version: "1.2.2",
  reason: "the filter walks every Enumerable as a hash, so an array param that holds a filtered name raises",
  upstream: nil,
)
