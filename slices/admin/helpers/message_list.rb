# frozen_string_literal: true

module Admin
  module Helpers
    module MessageList
      module_function

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
