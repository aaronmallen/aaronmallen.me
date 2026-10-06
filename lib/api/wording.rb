# frozen_string_literal: true

module API
  module Wording
    CONTROL = "holds a control character"
    TAG_SEPARATOR = ","
    UNSAVED = "could not save the change"

    module_function

    def complaints(errors, table, named: false)
      errors.to_h { |field, codes| [field, codes.map { reason(table, field, it, named:) }] }
    end

    def missing(noun, id, by: "ID") = "no #{noun} has the #{by} #{id}"

    def reason(table, field, code, named: false)
      table.fetch(field, Blog::Constants::EMPTY_HASH).fetch(code) do
        plain = code == Blog::Contract::CONTROL ? CONTROL : code
        named ? "#{field} #{plain}" : plain
      end
    end

    def summary(complaints) = complaints.map { |field, (reason)| "#{field}: #{reason}" }.join("; ")

    def tag_list(tags) = Array(tags).join(TAG_SEPARATOR)
  end
end
