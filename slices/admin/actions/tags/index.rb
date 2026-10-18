# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Index < Action
        def handle(request, response)
          scope = Blog::Types::TagScopeParam[request.params[:scope]]
          query = Blog::Types::TrimmedText[request.params[:q]]

          response.redirect_to(Helpers::TagList.back(routes, scope, query, page_number(request)))
        end
      end
    end
  end
end
