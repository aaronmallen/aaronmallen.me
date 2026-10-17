# frozen_string_literal: true

module API
  module Helpers
    module Wording
      CONTROL = "holds a control character"
      INVALID = "is not valid"
      UNSAVED = "could not save the change"

      SNOOZE_REFUSALS = {
        invalid: "snoozed_until is not a time",
        past: "snoozed_until must be in the future",
      }.freeze

      SHARED = {
        Blog::Contract::BLANK => "is empty",
        Blog::Contract::CONTROL => CONTROL,
        Blog::Contract::SKIPPED => "falls in the hour the clocks skip in #{Blog::TimeZone::NAME}",
        Blog::Contract::UNKNOWN_MENTION => "mentions someone who is not in the directory",
      }.freeze

      module_function

      def complaints(errors, table, named: false)
        errors.to_h { |field, codes| [field, codes.map { reason(table, field, it, named:) }] }
      end

      def missing(noun, id, by: "ID") = "no #{noun} has the #{by} #{id}"

      def plain(code, reasons = SHARED) = reasons.fetch(code, INVALID)

      def reason(table, field, code, named: false)
        table.fetch(field, Blog::Constants::EMPTY_HASH).fetch(code) do
          named ? "#{field} #{plain(code)}" : plain(code)
        end
      end

      def summary(complaints) = complaints.map { |field, (reason)| "#{field}: #{reason}" }.join("; ")
    end
  end
end
