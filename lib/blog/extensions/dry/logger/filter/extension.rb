# frozen_string_literal: true

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

Dry::Logger::Filter.prepend(Blog::Extensions::Dry::Logger::Filter::Extension)
