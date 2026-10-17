# frozen_string_literal: true

module Admin
  module Actions
    module Files
      class UpdateGroup < Action
        SAVED = "files_page.toasts.group_saved"

        include Deps[
          edit_view: "ui.views.files.edit_group",
          save_share_group: "shares.operations.save_share_group",
          share_group_queries: "shares.repos.share_group_queries",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:group]]

          settle(response, save_share_group.call(id, params), SAVED, routes.path(:admin_files)) do |errors|
            invalid(response, id, params, errors)
          end
        end

        private

        def invalid(response, id, params, errors)
          group = share_group_queries.find(id)
          halt :not_found unless group

          response.status = :unprocessable_content
          response.render(edit_view, group:, values: values(params), errors:)
        end

        def values(params)
          files = Blog::Types::Fields[params[:files]].to_h do |file_id, fields|
            [file_id.to_s, Blog::Types::Fields[fields].transform_values { Blog::Types::Text[it] }]
          end
          { name: Blog::Types::Text[params[:name]], code: Blog::Types::Text[params[:code]], files: }
        end
      end
    end
  end
end
