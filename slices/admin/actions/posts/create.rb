# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Create < Action
        TOASTS = "post_form.toasts"

        include Deps[
          build_post_editor: "operations.build_post_editor",
          save_post: "posts.operations.save_post",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:post]]

          case save_post.call(params, intent: intent(request))
            in Success[outcome, post]
              saved(response, outcome, post)
            in Failure[:invalid, errors]
              response.status = 422
              response.render(view, **build_post_editor.call(params:, errors:, view: request.params[:view]))
            else halt 500
          end
        end

        private

        def intent(request) = Blog::Types::PostIntentParam[request.params[:intent]]

        def saved(response, outcome, post)
          date = i18n.l(Blog::TimeZone.local(post.published_at), format: :medium) if post.published_at

          toast(response, "#{TOASTS}.#{outcome}", date:)
          response.redirect_to(routes.path(:admin_edit_post, id: post.id))
        end
      end
    end
  end
end
