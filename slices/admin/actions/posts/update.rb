# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Update < Action
        TOASTS = "post_form.toasts"

        include Deps[
          build_post_editor: "operations.build_post_editor",
          post_by_id: "posts.queries.by_id",
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
          post = post_by_id.call(id)
          halt 404 unless post

          response.status = 422
          response.render(view, **build_post_editor.call(post:, params:, errors:, view: request.params[:view]))
        end

        def saved(response, outcome, post)
          date = i18n.l(Blog::TimeZone.local(post.published_at), format: :medium) if post.published_at

          toast(response, "#{TOASTS}.#{outcome}", date:)
          response.redirect_to(routes.path(:admin_edit_post, id: post.id))
        end
      end
    end
  end
end
