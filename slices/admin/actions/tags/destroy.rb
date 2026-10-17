# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Destroy < Action
        KEPT = "tags_page.toasts.kept"
        REMOVED = "tags_page.toasts.removed"
        SEPARATOR = ", "

        include Deps[remove_tag: "tags.operations.remove_tag", tag_queries: "tags.repos.tag_queries"]

        def handle(request, response)
          scope = Blog::Types::TagScopeParam[request.params[:scope]]

          result = remove_tag.call(record_id(request), scope:)
          path = back_here(request) || list_path(request, scope)

          case result
            in Failure[:last_tag_of_rules, patterns]
              toast(response, KEPT, count: patterns.size, rules: patterns.join(SEPARATOR))
              response.redirect_to(path)
            else settle(response, result, REMOVED, path)
          end
        end

        private

        def list_path(request, scope)
          query = Blog::Types::TrimmedText[request.params[:q]]
          page = landing(request) { it.offset >= tag_queries.count_matching(scope, query.downcase) }

          Helpers::TagList.back(routes, scope, query, page)
        end
      end
    end
  end
end
