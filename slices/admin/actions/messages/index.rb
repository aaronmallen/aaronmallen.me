# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Index < Action
        PRIVATE = Blog::Types::TagScope["private"]

        include Deps[
          "settings",
          message_queries: "contact.repos.message_queries",
          tag_queries: "tags.repos.tag_queries",
        ]

        def handle(request, response)
          list = Helpers::MessageList.from(request.params)
          messages = message_queries.page_listed(page(request, response), **list)
          not_found(response) if messages.past_end?

          response[:count] = message_queries.count_listed(**list)
          response[:list] = list
          response[:messages] = messages
          response[:tag_names] = message_queries.tag_names
          show_open(request, response)
        end

        private

        def opened(request)
          id = Blog::Types::IdParam[request.params[:open]]
          message_queries.by_id(id) if id
        end

        def page(request, response) = requested_page(request, response, settings.page_size[:admin])

        def show_open(request, response)
          message = opened(request)

          response[:open] = message
          response[:tags] = message ? tag_queries.all_in(PRIVATE) : []
        end
      end
    end
  end
end
