# frozen_string_literal: true

module Shares
  module Operations
    class SaveShortLink < Blog::Operation
      include Deps[
        "operations.change_short_link_code", "operations.retarget_short_link", "operations.set_short_link_title",
      ]

      def call(id, params)
        transaction do
          step retarget_short_link.call(id, params)
          step change_short_link_code.call(id, params)
          step set_short_link_title.call(id, params)
        end
      end
    end
  end
end
