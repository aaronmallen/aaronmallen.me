# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Messages
      BULK = Schema.bulk("messages")
      UNCHANGED = "could not change message %s"
    end
  end
end
