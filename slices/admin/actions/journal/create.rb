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
            else halt 500
          end
        end

        private

        def invalid(request, response, params, errors)
          response.status = 422
          values = values(params)
          return response.render(index_view, **summarize_journal.call, values:, errors:) unless modal?(request)

          written = { body: values[:body], tags: values[:tags], errors:, return_to: wanted_path(request) }
          response.render(index_view, **summarize_journal.call, written:)
        end

        def modal?(request) = Blog::Types::Checkbox[request.params[:modal]]

        def return_path(request) = wanted_path(request) || routes.path(:admin_journal)

        def values(params)
          {
            body: Blog::Types::Text[params[:body]],
            entry_date: Blog::Types::DateParam[params[:entry_date]],
            tags: Blog::Types::Text[params[:tags]],
          }
        end

        def wanted_path(request) = auth_session(request).admin_return_path(request.params[:return_to])
      end
    end
  end
end
