# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Suggestions
      POST = "post"
      SENT = "the social post under suggestion %s has been sent"
      SOCIAL_POST = "social_post"
      TARGET = { type: "string", enum: [POST, SOCIAL_POST] }.freeze
    end
  end
end
