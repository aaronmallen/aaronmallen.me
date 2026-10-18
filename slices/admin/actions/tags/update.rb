# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Update < Action
        RECOLOURED = "tags_page.toasts.recoloured"
        RENAMED = "tags_page.toasts.renamed"

        include Deps[
          "operations.build_tagging_page",
          tagging_view: "ui.views.settings.tagging",
          save_tag: "tags.operations.save_tag",
          tag_queries: "tags.repos.tag_queries",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:tag]]
          scope = Blog::Types::TagScopeParam[request.params[:scope]]
          query = Blog::Types::TrimmedText[request.params[:q]]

          result = save_tag.call(params, scope:, id:)

          settle(response, result, saved_key(params), back(request, scope, query)) do |errors|
            invalid(request, response, scope, query, editing(id, params, errors))
          end
        end

        private

        def back(request, scope, query)
          back_to_section(request, :admin_settings_tagging, Helpers::TagList::TAGS) || list_path(request, scope, query)
        end

        def editing(id, params, errors)
          { errors:, id:, name: Blog::Types::Text[params[:name]], **params.slice(:description) }
        end

        def invalid(request, response, scope, query, editing)
          page = requested_page(request, response)
          unprocessable(response, tagging_view, **build_tagging_page.call(tags: { scope:, page:, editing:, query: }))
        end

        def list_path(request, scope, query)
          page = landing(request) { it.offset >= tag_queries.count_matching(scope, query.downcase) }

          Helpers::TagList.back(routes, scope, query, page)
        end

        def saved_key(params) = Blog::Types::Text[params[:color]].empty? ? RENAMED : RECOLOURED
      end
    end
  end
end
