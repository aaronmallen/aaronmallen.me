# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Posts
      MOST_IDS = 100
      IDS = {
        type: "array",
        items: Schema::ID,
        minItems: 1,
        maxItems: MOST_IDS,
        description: "the blog posts to change, #{MOST_IDS} at most; one that fails changes none".freeze,
      }.freeze
      BULK = { additionalProperties: false, properties: { ids: IDS }, required: ["ids"] }.freeze
      TAG = { type: "string", description: "one public tag, lowercase words" }.freeze
      UNSAVED = "could not save the change"

      COMPLAINTS = {
        tag: { "blank" => "name the tag first", Blog::Contract::FORMAT => "a tag is lowercase words" },
      }.freeze

      module_function

      def complaints(errors) = errors.to_h { |field, codes| [field, codes.map { reason(field, it) }] }

      def missing(id) = "no blog post has the ID #{id}"

      def reason(field, code) = COMPLAINTS.fetch(field, Blog::Constants::EMPTY_HASH).fetch(code, code)

      def summary(complaints) = complaints.map { |field, (reason)| "#{field}: #{reason}" }.join("; ")
    end
  end
end
