# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module SavedViews
      ID = Helpers::Schema::ID
      UNSAVED = "could not save the saved view"

      COMPLAINTS = {
        filters: { Blog::Contract::CONTROL => "filters hold a control character" },
        name: { "blank" => "name needs a character that is not a space", "long" => "name runs past 100 characters" },
      }.freeze

      FILTERS = {
        type: "object",
        properties: { types: { type: "object", additionalProperties: Helpers::Schema::STRING } },
        additionalProperties: Helpers::Schema::STRING,
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
    end
  end
end
