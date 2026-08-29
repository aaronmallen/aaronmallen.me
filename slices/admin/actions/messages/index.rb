# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Index < Action
        include Deps[messages_by_status: "contact.queries.by_status"]

        def handle(request, response)
          filter = Blog::Types::MessageStatusParam[request.params[:status]]

          response[:filter] = filter
          response[:messages] = messages_by_status.call(filter)
        end
      end
    end
  end
end
