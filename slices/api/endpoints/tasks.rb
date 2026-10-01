# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Tasks
      CONTROL = "holds a control character"
      DIRECTIONS = Blog::Types::TaskMove.values.freeze
      ID = { type: "integer" }.freeze
      LISTS = Blog::Types::TaskFilter.values.freeze
      SPRINT_PAST = "a sprint opens on today or a day after it"
      TAG_SEPARATOR = ","
      UNSAVED = "could not save the change"

      COMPLAINTS = {
        list: { Blog::Contract::FORMAT => "pick one of the four lists" },
        tags: { Blog::Contract::FORMAT => "tags are lowercase words" },
        title: { "blank" => "write the task down first" },
      }.freeze

      module_function

      def complaints(errors) = errors.to_h { |field, codes| [field, codes.map { reason(field, it) }] }

      def missing(id) = "no task has the ID #{id}"

      def reason(field, code)
        return CONTROL if code == Blog::Contract::CONTROL

        COMPLAINTS.fetch(field, Blog::Constants::EMPTY_HASH).fetch(code, code)
      end

      def summary(complaints) = complaints.map { |field, (reason)| "#{field}: #{reason}" }.join("; ")

      def tag_list(tags) = Array(tags).join(TAG_SEPARATOR)
    end
  end
end
