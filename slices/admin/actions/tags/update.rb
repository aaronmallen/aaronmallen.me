# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Update < Action
        RECOLOURED = "tags_page.toasts.recoloured"
        RENAMED = "tags_page.toasts.renamed"

        include Deps[
          "settings",
          build_tags_page: "operations.build_tags_page",
          index_view: "ui.views.tags.index",
          save_tag: "tags.operations.save_tag",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:tag]]
          scope = Blog::Types::TagScopeParam[request.params[:scope]]

          case save_tag.call(params, scope:, id:)
          in Success(_) then saved(response, scope, params)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then invalid(request, response, scope, editing(id, params, errors))
          else halt 500
          end
        end

        private

        def editing(id, params, errors) = { errors:, id:, name: Blog::Types::Text[params[:name]] }

        def invalid(request, response, scope, editing)
          page = requested_page(request, response, settings.page_size[:admin])
          response.status = 422
          response.render(index_view, **build_tags_page.call(scope:, page:, editing:))
        end

        def saved(response, scope, params)
          toast(response, Blog::Types::Text[params[:color]].empty? ? RENAMED : RECOLOURED)
          response.redirect_to(routes.path(:admin_tags, scope:))
        end
      end
    end
  end
end
