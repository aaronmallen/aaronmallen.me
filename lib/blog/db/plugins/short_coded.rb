# frozen_string_literal: true

module Blog
  module DB
    module Plugins
      module ShortCoded
        def with_code = qualified.join(:short_codes).select_append { |short_codes:| short_codes[:code] }
      end
    end
  end
end
