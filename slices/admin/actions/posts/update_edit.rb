# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class UpdateEdit < Action
        SAVED = "post_form.toasts.note_saved"

        include Deps[
          build_post_editor: "operations.build_post_editor",
          post_by_id: "posts.queries.by_id",
          revise_edit_note: "posts.operations.revise_edit_note",
          view: "ui.views.posts.edit",
        ]

        def handle(request, response)
          post = post_by_id.call(record_id(request)) || halt(404)
          id = edit_id(request)
          params = Blog::Types::Fields[request.params[:edit]]

          case revise_edit_note.call(post.id, id, params)
          in Success(_) then saved(response, post)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then invalid(response, post, id:, note: params[:note], errors:)
          else halt 500
          end
        end

        private

        def edit_id(request) = Blog::Types::IdParam[request.params[:edit_id]] || halt(404)

        def invalid(response, post, id:, note:, errors:)
          noting = { id:, note: Blog::Types::Text[note], errors: }

          response.status = 422
          response.render(view, **build_post_editor.call(post:, noting:))
        end

        def saved(response, post)
          toast(response, SAVED)
          response.redirect_to(routes.path(:admin_edit_post, id: post.id))
        end
      end
    end
  end
end
