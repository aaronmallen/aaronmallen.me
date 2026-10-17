# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class Create < Action
        SAVED = "journal_page.toasts.saved"

        include Deps[
          index_view: "ui.views.journal.index",
          save_journal_entry: "record.operations.save_journal_entry",
          summarize_journal: "operations.summarize_journal",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:entry]]
          params = params.slice(:body, :tags) if modal?(request)

          case save_journal_entry.call(params)
            in Success(_)
              toast(response, SAVED)
              response.redirect_to(return_path(request))
            in Failure[:invalid, errors] then invalid(request, response, params, errors)
            else halt :internal_server_error
          end
        end

        private

        def invalid(request, response, params, errors)
          response.status = :unprocessable_content
          values = values(params)
          return response.render(index_view, **summarize_journal.call, values:, errors:) unless modal?(request)

          written = { body: values[:body], tags: values[:tags], errors:, return_to: back_here(request) }
          response.render(index_view, **summarize_journal.call, written:)
        end

        def modal?(request) = Blog::Types::Checkbox[request.params[:modal]]

        def return_path(request) = back_here(request) || routes.path(:admin_journal)

        def values(params)
          {
            body: Blog::Types::Text[params[:body]],
            entry_date: Blog::Types::DateParam[params[:entry_date]],
            tags: Blog::Types::Text[params[:tags]],
          }
        end
      end
    end
  end
end
