# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module JournalEntries
      ID = Helpers::Schema::ID

      COMPLAINTS = {
        body: { Blog::Contract::BLANK => "body needs a character that is not a space" },
        entry_date: {
          Blog::Contract::FORMAT => "entry_date needs a day, such as 2026-01-01",
          "future" => "entry_date falls after today; pick today or an earlier day",
        },
        tags: { Blog::Contract::FORMAT => "tags take lowercase letters, numbers and single dashes in each tag" },
      }.freeze

      TAGS = {
        type: "array",
        items: { type: "string" },
        description: "tag names, such as ruby or health, in lowercase letters, numbers and single dashes",
      }.freeze
    end
  end
end
