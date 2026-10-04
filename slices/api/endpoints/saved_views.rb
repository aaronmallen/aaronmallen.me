# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module SavedViews
      ID = { type: "integer" }.freeze
      UNSAVED = "could not save the saved view"

      COMPLAINTS = {
        [:name, "blank"] => "name needs a character that is not a space",
        [:name, Blog::Contract::CONTROL] => "name holds a control character",
        [:name, "long"] => "name runs past 100 characters",
      }.freeze

      FILTERS = {
        type: "object",
        properties: { types: { type: "object", additionalProperties: Schema::STRING } },
        additionalProperties: Schema::STRING,
        description: [
          "the screen's filters as its URL params take them, such as {\"q\": \"deploy\"}; activity's types",
          "takes an object, such as {\"post\": \"1\"}, and a filter the screen does not read is dropped",
        ].join(" "),
      }.freeze

      NAME = { type: "string", description: "what the view is called, up to 100 characters" }.freeze

      SCREEN = {
        type: "string",
        enum: Blog::Types::SavedViewScreen.values,
        description: "the admin screen the view opens",
      }.freeze

      module_function

      def complaints(errors)
        errors.to_h { |field, tokens| [field, tokens.map { COMPLAINTS.fetch([field, it]) { "#{field} #{it}" } }] }
      end

      def missing(id) = "no saved view has the ID #{id}"
    end
  end
end
