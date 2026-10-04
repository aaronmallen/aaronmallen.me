# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module JournalEntries
      ID = Schema::ID
      TAG_SEPARATOR = ","

      COMPLAINTS = {
        [:body, Blog::Contract::BLANK] => "body needs a character that is not a space",
        [:body, Blog::Contract::CONTROL] => "body holds a control character",
        [:entry_date, Blog::Contract::FORMAT] => "entry_date needs a day, such as 2026-01-01",
        [:entry_date, "future"] => "entry_date falls after today; pick today or an earlier day",
        [:tags, Blog::Contract::FORMAT] => "tags take lowercase letters, numbers and single dashes in each tag",
      }.freeze

      TAGS = {
        type: "array",
        items: { type: "string" },
        description: "tag names, such as ruby or health, in lowercase letters, numbers and single dashes",
      }.freeze

      module_function

      def complaints(errors)
        errors.to_h { |field, tokens| [field, tokens.map { COMPLAINTS.fetch([field, it]) { "#{field} #{it}" } }] }
      end

      def missing(id) = "no journal entry has the ID #{id}"

      def tag_list(tags) = Array(tags).join(TAG_SEPARATOR)
    end
  end
end
