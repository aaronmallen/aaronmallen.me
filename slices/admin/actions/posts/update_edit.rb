# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class UpdateEdit < Action
        KIND = Blog::Types::RecordKind["post"]
        SAVED = "post_form.toasts.note_saved"

        include Deps[
          build_post_editor: "operations.build_post_editor",
          list_record_links: "operations.list_record_links",
          post_by_id: "posts.queries.by_id",
          revise_edit_note: "posts.operations.revise_edit_note",
          view: "ui.views.posts.edit",
        ]

        def handle(request, response)
          post = post_by_id.call(record_id(request)) || halt(404)
          id = edit_id(request)
          params = Blog::Types::Fields[request.params[:edit]]

          result = revise_edit_note.call(post.id, id, params)

          case result
          in Failure[:invalid, errors] then invalid(response, post, id:, note: params[:note], errors:)
          else settle(response, result, SAVED, post_path(post))
          end
        end

        private

        def edit_id(request) = Blog::Types::IdParam[request.params[:edit_id]] || halt(404)

        def invalid(response, post, id:, note:, errors:)
          noting = { id:, note: Blog::Types::Text[note], errors: }

          response.status = 422
          response.render(view, **build_post_editor.call(post:, noting:),
records: list_record_links.call(KIND, post.id))
        end

        def post_path(post) = routes.path(:admin_edit_post, id: post.id)
      end
    end
  end
end
