# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Index < Action
        include Deps["settings", message_queries: "contact.repos.message_queries"]

        def handle(request, response)
          filter = Blog::Types::MessageStatusParam[request.params[:status]]
          messages = message_queries.page_by_status(filter, page(request, response))
          not_found(response) if messages.past_end?

          response[:count] = message_queries.count_with_status(filter)
          response[:filter] = filter
          response[:messages] = messages
          response[:open] = opened(request)
        end

        private

        def opened(request)
          id = Blog::Types::IdParam[request.params[:open]]
          message_queries.by_id(id) if id
        end

        def page(request, response) = requested_page(request, response, settings.page_size[:admin])
      end
    end
  end
end
