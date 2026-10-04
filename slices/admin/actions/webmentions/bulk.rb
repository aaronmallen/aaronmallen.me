# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class Bulk < Action
        BLANK = "blank"
        DONE = {
          Blog::Types::WebmentionVerdict["approved"] => "webmentions_page.toasts.bulk.approved",
          Blog::Types::WebmentionVerdict["ignored"] => "webmentions_page.toasts.bulk.ignored",
          Blog::Types::WebmentionVerdict["spam"] => "webmentions_page.toasts.bulk.spam",
        }.freeze
        FAILED = "webmentions_page.toasts.bulk.failed"
        FORMAT = "format"
        INVALID = "webmentions_page.toasts.bulk.invalid"
        KEY = "#"
        LONG = "long"
        REASONS = %i[not_found].freeze

        include Deps[
          "settings",
          act_on_webmentions: "social.operations.act_on_webmentions",
          webmentions_by_status: "social.queries.webmentions_by_status",
        ]

        def handle(request, response)
          case act_on_webmentions.call(request.params.to_h)
          in Success[*mentions] then toast(response, DONE.fetch(request.params[:act]), count: mentions.size)
          in Failure[:record, id, reason] then failed(response, id, reason)
          in Failure[:invalid, errors] then toast(response, "#{INVALID}.#{refused(errors)}")
          else halt 500
          end

          response.redirect_to(back(request))
        end

        private

        def back(request)
          status = Blog::Types::WebmentionStatusParam[request.params[:status]]

          routes.path(:admin_webmentions, status:, **Blog::Page.query(landing(request, status)))
        end

        def failed(response, id, reason)
          code = REASONS.include?(reason) ? reason : :other

          toast(response, "#{FAILED}.#{code}", mention: "#{KEY}#{id}")
        end

        def landing(request, status)
          number = Blog::Types::PageParam.call(request.params[:page]) { 1 }
          return number if number == 1

          page = Blog::Page.new(number:, size: settings.page_size[:admin])
          webmentions_by_status.call(status, page).past_end? ? number - 1 : number
        end

        def refused(errors)
          case errors
          in { ids: [LONG, *] } then LONG
          in { ids: [::String, *] } then BLANK
          else FORMAT
          end
        end
      end
    end
  end
end
