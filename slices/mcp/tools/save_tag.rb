# frozen_string_literal: true

module MCP
  module Tools
    class SaveTag < Base
      UNSAVED = "could not save the tag"

      MESSAGES = {
        color: { "format" => "pick one of the six colours" },
        name: {
          "blank" => "give the tag a name first",
          "format" => "a tag is lowercase words joined by hyphens",
          "taken" => "another tag already holds that name",
        },
      }.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          color: { type: "string", enum: Blog::Types::TagColor.values },
          id: API::Schema::ID.merge(description: "the tag to rename or recolour; leave it out to add a new one"),
          name: { type: "string", description: "lowercase words joined by hyphens" },
          scope: TAG_SCOPE,
        },
        required: ["scope"],
      }.freeze

      description "Add a tag to a scope, or rename or recolour one in it when you give its id. Public tags go on " \
                  "posts and projects; private tags go on journal entries and tasks. A new tag needs a name and " \
                  "takes the least used colour in its scope unless you give one. On a change, a field you leave " \
                  "out keeps what it has, and a rename follows the tag onto every record that carries it"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(scope:, server_context:, id: nil, name: nil, color: nil)
          current = id && dep(:tag_by_id, server_context).call(id, scope:)
          return refuse(missing(id)) if id && current.nil?

          saved(dep(:save_tag, server_context).call({ name: name || current&.name, color: }, scope:, id:), id)
        end

        private

        def missing(id) = "no tag has the ID #{id}"

        def saved(result, id)
          case result
          in Success(tag) then answer(id: tag.id, name: tag.name, color: tag.color)
          in Failure[:invalid, errors] then refuse(Complaints.call(errors, MESSAGES))
          in Failure(:not_found) then refuse(missing(id))
          else refuse(UNSAVED)
          end
        end
      end
    end
  end
end
