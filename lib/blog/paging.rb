# frozen_string_literal: true

module Blog
  module Paging
    USAGE = "Rows come a page at a time. When more remain, partial comes back true and next_page holds the " \
            "number to send as page for the rest"
    PAGE = { type: "integer", minimum: 1, description: "the page to read, counting from 1; 1 when left out" }.freeze

    module_function

    def fields(*pages)
      return { partial: false } unless pages.any?(&:more)

      { partial: true, next_page: pages.first.number + 1 }
    end
  end
end
