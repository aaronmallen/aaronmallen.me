# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Bulk < Action
        DONE = {
          Blog::Types::MessageBulkAction["delete"] => "messages_page.toasts.bulk.deleted",
          Blog::Types::MessageBulkAction["read"] => "messages_page.toasts.bulk.read",
          Blog::Types::MessageBulkAction["unread"] => "messages_page.toasts.bulk.unread",
        }.freeze
        FAILED = "messages_page.toasts.bulk.failed"
        INVALID = "messages_page.toasts.bulk.invalid"
        KEY = "#"
        LONG = "long"
        REASONS = %i[not_found].freeze

        include Deps[
          "settings",
          act_on_messages: "contact.operations.act_on_messages",
          message_by_id: "contact.queries.by_id",
          messages_by_status: "contact.queries.by_status",
        ]

        def handle(request, response)
          case act_on_messages.call(request.params.to_h)
          in Success[*messages] then toast(response, DONE.fetch(request.params[:act]), count: messages.size)
          in Failure[:record, id, reason] then failed(response, id, reason)
          in Failure[:invalid, errors] then toast(response, "#{INVALID}.#{refused(errors)}")
          else halt 500
          end

          response.redirect_to(back(request))
        end

        private

        def back(request)
          status = Blog::Types::MessageStatusParam[request.params[:status]]

          routes.path(:admin_messages, status:, **Blog::Page.query(landing(request, status)))
        end

        def failed(response, id, reason)
          name = ["#{KEY}#{id}", message_by_id.call(id)&.subject].compact.join(" ")
          code = REASONS.include?(reason) ? reason : :other

          toast(response, "#{FAILED}.#{code}", message: name)
        end

        def landing(request, status)
          number = Blog::Types::PageParam.call(request.params[:page]) { 1 }
          return number if number == 1

          page = Blog::Page.new(number:, size: settings.page_size[:admin])
          messages_by_status.call(status, page).past_end? ? number - 1 : number
        end

        def refused(errors)
          case errors
          in { ids: [LONG, *] } then LONG
          in { ids: [::String, *] } then Blog::Contract::BLANK
          else Blog::Contract::FORMAT
          end
        end
      end
    end
  end
end
