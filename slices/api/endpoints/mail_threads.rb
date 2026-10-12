# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module MailThreads
      BULK = Helpers::Schema.bulk("mail threads")
      COMPLAINTS = { tag: Helpers::Tags::COMPLAINTS }.freeze
      TAG = Helpers::Tags.schema("private")
      UNCHANGED = "could not change mail thread %s"
    end
  end
end
