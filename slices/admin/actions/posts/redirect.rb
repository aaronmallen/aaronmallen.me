# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      module Redirect
        private

        def back(request)
          filter = Blog::Types::PostFilterParam[request.params[:status]]
          page = landing(request) { post_queries.by_filter(filter, it).past_end? }

          routes.path(:admin_posts, status: filter, **Blog::Structs::Page.query(page))
        end
      end
    end
  end
end
