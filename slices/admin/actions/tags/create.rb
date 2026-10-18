# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Create < Action
        ADDED = "tags_page.toasts.added"

        include Deps[
          "operations.build_tagging_page",
          tagging_view: "ui.views.settings.tagging",
          save_tag: "tags.operations.save_tag",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:tag]]
          scope = Blog::Types::TagScopeParam[request.params[:scope]]

          back = Helpers::TagList.back(routes, scope, "", 1)

          settle(response, save_tag.call(params, scope:), ADDED, back) do |errors|
            unprocessable(response, tagging_view, **build_tagging_page.call(tags: { scope:, errors:, params: }))
          end
        end
      end
    end
  end
end
