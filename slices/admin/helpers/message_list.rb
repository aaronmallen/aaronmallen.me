# frozen_string_literal: true

module Admin
  module Helpers
    module MessageList
      module_function

      def anchor(id) = "read-#{id}"

      def back(routes, list, open: nil, **query)
        path = routes.path(:admin_messages, **list, **query, **({ open: } if open))

        open ? "#{path}##{anchor(open)}" : path
      end

      def from(params, status_key = :status)
        {
          status: Blog::Types::MessageFilterParam[params[status_key]],
          search: Blog::Types::OptionalText[params[:search]],
          tag: Blog::Types::OptionalText[params[:tag]],
        }.compact
      end
    end
  end
end
