# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Update < Action
        KIND = Blog::Types::RecordKind["post"]

        include Deps[
          build_post_editor: "operations.build_post_editor",
          describe_post_save: "operations.describe_post_save",
          list_record_links: "operations.list_record_links",
          post_queries: "posts.repos.post_queries",
          save_post: "posts.operations.save_post",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:post]]

          case save_post.call(params, id:, intent: intent(request))
            in Success[outcome, post] then saved(response, outcome, post)
            in Failure(:not_found) then halt 404
            in Failure[:invalid, errors] then invalid(request, response, params, errors, id:)
            else halt 500
          end
        end

        private

        def intent(request) = Blog::Types::PostIntentParam[request.params[:intent]]

        def invalid(request, response, params, errors, id:)
          post = post_queries.by_id(id)
          halt 404 unless post

          response.status = 422
          editor = build_post_editor.call(post:, params:, errors:, view: request.params[:view])
          response.render(view, **editor, records: list_record_links.call(KIND, id))
        end

        def saved(response, outcome, post)
          key, options = describe_post_save.call(outcome, post)

          toast(response, key, **options)
          response.redirect_to(routes.path(:admin_edit_post, id: post.id))
        end
      end
    end
  end
end
