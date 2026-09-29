# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Index < Action
        include Deps[
          "settings",
          count_with_status: "contact.queries.count_with_status",
          messages_by_status: "contact.queries.by_status",
        ]

        def handle(request, response)
          filter = Blog::Types::MessageStatusParam[request.params[:status]]
          messages = messages_by_status.call(filter, requested_page(request, response, settings.page_size[:admin]))
          not_found(response) if messages.past_end?

          response[:count] = count_with_status.call(filter)
          response[:filter] = filter
          response[:messages] = messages
        end
      end
    end
  end
end
