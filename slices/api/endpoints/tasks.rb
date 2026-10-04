# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Tasks
      CONTROL = "holds a control character"
      DIRECTIONS = Blog::Types::TaskMove.values.freeze
      ID = { type: "integer" }.freeze
      MOST_IDS = 100
      IDS = {
        type: "array",
        items: ID,
        minItems: 1,
        maxItems: MOST_IDS,
        description: "the tasks to change, #{MOST_IDS} at most; one that fails changes none".freeze,
      }.freeze
      BULK = { additionalProperties: false, properties: { ids: IDS }, required: ["ids"] }.freeze
      LISTS = Blog::Types::TaskFilter.values.freeze
      SPRINT_PAST = "a sprint opens on today or a day after it"
      TAG = { type: "string", description: "one private tag, lowercase words" }.freeze
      TAG_SEPARATOR = ","
      UNSAVED = "could not save the change"

      COMPLAINTS = {
        body: { "blank" => "write the comment first" },
        kind: { Blog::Contract::FORMAT => "pick one of the four link types" },
        list: { Blog::Contract::FORMAT => "pick one of the four lists" },
        other_id: {
          Blog::Contract::FORMAT => "pick a task by its ID",
          "missing" => "that task is gone, so find another",
          "self" => "a task cannot link to itself",
          "taken" => "these two tasks are already linked",
        },
        tag: { "blank" => "name the tag first", Blog::Contract::FORMAT => "a tag is lowercase words" },
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
