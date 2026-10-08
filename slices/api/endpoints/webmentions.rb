# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Webmentions
      BULK = Helpers::Schema.bulk("webmentions")
      ID = Helpers::Schema::ID
    end
  end
end
