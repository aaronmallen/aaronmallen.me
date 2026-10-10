# frozen_string_literal: true

module API
  module Helpers
    module Page
      module_function

      def of(number) = Blog::Structs::Page.new(number:, size: Hanami.app.settings.page_size[:mcp])
    end
  end
end
