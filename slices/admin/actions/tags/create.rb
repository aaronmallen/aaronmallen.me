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

          case save_tag.call(params, scope:)
            in Success(_)
              added(response, scope)
            in Failure[:invalid, errors]
              invalid(response, scope, params, errors)
            else halt 500
          end
        end

        private

        def added(response, scope)
          toast(response, ADDED)
          response.redirect_to(routes.path(:admin_tags, scope:))
        end

        def invalid(response, scope, params, errors)
          response.status = 422
          response.render(index_view, **build_tags_page.call(scope:, errors:, params:))
        end
      end
    end
  end
end
