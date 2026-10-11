# frozen_string_literal: true

module API
  module Helpers
    module Page
      module_function

      def of(number, settings) = Blog::Structs::Page.new(number:, size: settings.page_size[:mcp])
    end
  end
end
