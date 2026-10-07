# frozen_string_literal: true

module Admin
  module Actions
    module Today
      class CreateJournalEntry < Action
        SAVED = "journal_page.toasts.saved"

        include Deps[
          save_journal_entry: "record.operations.save_journal_entry",
          show_view: "ui.views.today.show",
          summarize_today: "operations.summarize_today",
        ]

        def handle(request, response)
          fields = Blog::Types::Fields[request.params[:entry]].slice(:body, :tags)

          case save_journal_entry.call(fields)
            in Success(_) then saved(response)
            in Failure[:invalid, errors] then invalid(response, fields, errors)
            else halt 500
          end
        end

        private

        def invalid(response, fields, errors)
          response.status = 422

          case summarize_today.call
            in Success(summary) then response.render(show_view, **summary, **values(fields), errors:)
            else halt 500
          end
        end

        def saved(response)
          toast(response, SAVED)
          response.redirect_to(routes.path(:admin_root))
        end

        def values(fields) = { body: Blog::Types::Text[fields[:body]], tags: Blog::Types::Text[fields[:tags]] }
      end
    end
  end
end
