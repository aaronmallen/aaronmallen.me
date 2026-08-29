# frozen_string_literal: true

module Admin
  module Operations
    class CountUnreadMessages
      UNREAD = Blog::Types::MessageStatus["unread"]

      include Deps[count_messages_with_status: "contact.queries.count_with_status"]

      def call = count_messages_with_status.call(UNREAD)
    end
  end
end
