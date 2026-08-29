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

          case save_tag.call(params)
          in Success(_)
            added(response)
          in Failure[:invalid, errors]
            invalid(response, params, errors)
          else halt 500
          end
        end

        private

        def added(response)
          toast(response, ADDED)
          response.redirect_to(routes.path(:admin_tags))
        end

        def invalid(response, params, errors)
          response.status = 422
          response.render(index_view, **build_tags_page.call(errors:, params:))
        end
      end
    end
  end
end
