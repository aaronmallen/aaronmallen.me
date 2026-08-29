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
          body = Blog::Types::Fields[request.params[:entry]][:body]

          case save_journal_entry.call({ body: })
          in Success(_) then saved(response)
          in Failure[:invalid, errors] then invalid(response, body, errors)
          else halt 500
          end
        end

        private

        def invalid(response, body, errors)
          response.status = 422

          case summarize_today.call
          in Success(summary) then response.render(show_view, **summary, body: Blog::Types::Text[body], errors:)
          else halt 500
          end
        end

        def saved(response)
          toast(response, SAVED)
          response.redirect_to(routes.path(:admin_root))
        end
      end
    end
  end
end
