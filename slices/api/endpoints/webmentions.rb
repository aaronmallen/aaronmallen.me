# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Webmentions
      BULK = Schema.bulk("webmentions")
      ID = Schema::ID
    end
  end
end
