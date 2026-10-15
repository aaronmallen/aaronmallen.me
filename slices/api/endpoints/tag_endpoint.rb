# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class TagEndpoint < Endpoint
      PRIVATE_KINDS = "journal entries, tasks, decisions and task rules"
      SCOPE = {
        type: "string",
        enum: Blog::Types::TagScope.values,
        description: "public holds the tags on posts and projects; private holds those on #{PRIVATE_KINDS}",
      }.freeze

      COMPLAINTS = {
        color: { Blog::Contract::FORMAT => "pick one of the six colours" },
        name: {
          Blog::Contract::BLANK => "give the tag a name first",
          Blog::Contract::FORMAT => Helpers::Tags::REFUSAL,
          "taken" => "another tag already holds that name",
        },
      }.freeze

      PROPERTIES = {
        color: { type: "string", enum: Blog::Types::TagColor.values },
        name: { type: "string", description: Helpers::Tags::FORMAT },
        scope: SCOPE,
      }.freeze

      REPLY = Helpers::Schema.object(
        { id: Helpers::Schema::INTEGER, name: Helpers::Schema::STRING, color: Helpers::Schema::STRING },
      ).freeze

      private

      def saved(result, id = nil)
        case result
          in Success(tag) then Success(id: tag.id, name: tag.name, color: tag.color)
          in Failure[:invalid, errors] then rejected(errors, COMPLAINTS)
          in Failure(:not_found) then missing("tag", id)
          else failed("could not save the tag")
        end
      end
    end
  end
end
