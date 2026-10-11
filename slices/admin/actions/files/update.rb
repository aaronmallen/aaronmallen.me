# frozen_string_literal: true

module Admin
  module Actions
    module Files
      class Update < Action
        SAVED = "files_page.toasts.saved"

        include Deps[
          edit_view: "ui.views.files.edit",
          save_share: "shares.operations.save_share",
          share_queries: "shares.repos.share_queries",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:share]]

          case save_share.call(id, params)
            in Failure[:invalid, errors] then invalid(response, id, params, errors)
            in result then settle(response, result, SAVED, routes.path(:admin_files))
          end
        end

        private

        def invalid(response, id, params, errors)
          share = share_queries.find(id)
          halt 404 unless share

          values = { code: Blog::Types::Text[params[:code]], alt_text: Blog::Types::Text[params[:alt_text]] }
          response.status = 422
          response.render(edit_view, share:, values:, errors:)
        end
      end
    end
  end
end
