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

          case save_journal_entry.call(params)
          in Success(_)
            toast(response, SAVED)
            response.redirect_to(routes.path(:admin_journal))
          in Failure[:invalid, errors]
            response.status = 422
            response.render(index_view, **summarize_journal.call, values: values(params), errors:)
          else halt 500
          end
        end

        private

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
