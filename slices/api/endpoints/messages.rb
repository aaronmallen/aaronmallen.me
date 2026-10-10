# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Messages
      BULK = Helpers::Schema.bulk("messages")
      COMPLAINTS = { tag: Helpers::Tags::COMPLAINTS }.freeze
      TAG = Helpers::Tags.schema("private")
      UNCHANGED = "could not change message %s"
    end
  end
end
