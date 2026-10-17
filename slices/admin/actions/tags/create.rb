# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Create < Action
        ADDED = "tags_page.toasts.added"

        include Deps[
          build_tags_page: "operations.build_tags_page",
          index_view: "ui.views.tags.index",
          save_tag: "tags.operations.save_tag",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:tag]]
          scope = Blog::Types::TagScopeParam[request.params[:scope]]

          settle(response, save_tag.call(params, scope:), ADDED, routes.path(:admin_tags, scope:)) do |errors|
            unprocessable(response, index_view, **build_tags_page.call(scope:, errors:, params:))
          end
        end
      end
    end
  end
end
