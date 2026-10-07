# frozen_string_literal: true

module Admin
  module Actions
    module Review
      class SaveNote < Action
        MONTH = Blog::Types::ReviewPeriod["month"]
        SAVED = "review_page.toasts.saved"

        include Deps[
          build_review_page: "operations.build_review_page",
          save_review_note: "record.operations.save_review_note",
          show_view: "ui.views.review.show",
        ]

        def handle(request, response)
          params = request.params
          period = Blog::Types::ReviewPeriodParam[params[:period]]
          on = Blog::Types::DateParam[params[:day]] || halt(400)
          body = Blog::Types::Text[Blog::Types::Fields[params[:note]][:body]]

          case save_review_note.call(body, period:, on:)
            in Success(_) then saved(response, period, on)
            in Failure[:invalid, errors] then invalid(response, period, on, body, errors)
            else halt 500
          end
        end

        private

        def invalid(response, period, on, body, errors)
          response.status = 422
          page = build_review_page.call(period:, day: on.iso8601)

          response.render(show_view, **page, note_body: body, errors:)
        end

        def review_params(period, on) = { period: (period if period == MONTH), day: on.iso8601 }.compact

        def saved(response, period, on)
          toast(response, SAVED)
          response.redirect_to(routes.path(:admin_review, **review_params(period, on)))
        end
      end
    end
  end
end
