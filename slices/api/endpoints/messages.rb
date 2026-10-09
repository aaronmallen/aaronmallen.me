# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Messages
      BULK = Helpers::Schema.bulk("messages")
      COMPLAINTS = {
        tag: { "blank" => "name the tag first", Blog::Contract::FORMAT => "a tag is lowercase words" },
      }.freeze
      TAG = { type: "string", description: "one private tag, lowercase words" }.freeze
      UNCHANGED = "could not change message %s"
    end
  end
end
