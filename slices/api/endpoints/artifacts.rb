# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Artifacts
      BODY_LIMIT = ::Agents::Contracts::ArtifactContract::BODY_LIMIT
      NOTE_LIMIT = ::Agents::Contracts::ArtifactVersionContract::NOTE_LIMIT
      TITLE_LIMIT = ::Agents::Contracts::ArtifactContract::TITLE_LIMIT
      BODY = { type: "string", description: "the body, in Markdown, #{BODY_LIMIT} characters at most" }.freeze
      NOTE = { type: "string", description: "what the change does, #{NOTE_LIMIT} characters at most" }.freeze
      TAGS = Helpers::Schema::TAGS.merge(description: "its tags, #{Helpers::Tags::FORMAT}").freeze
      TITLE = { type: "string", description: "its title, #{TITLE_LIMIT} characters at most" }.freeze
      TYPE = { type: "string", enum: Blog::Types::ArtifactType.values }.freeze

      CONTRACTS = [::Agents::Contracts::ArtifactContract, ::Agents::Contracts::ArtifactVersionContract].freeze
      COMPLAINTS = {
        **Memory::COMPLAINTS.slice(:agent, :model, :session_id),
        body: {
          Blog::Contract::BLANK => "write the body first",
          "long" => "keep a body to #{BODY_LIMIT} characters",
        },
        note: { "long" => "keep a note to #{NOTE_LIMIT} characters" },
        tags: Helpers::Tags::COMPLAINTS,
        title: {
          Blog::Contract::BLANK => "name the artifact first",
          "long" => "keep a title to #{TITLE_LIMIT} characters",
        },
      }.freeze

      REPLY = Helpers::Schema.widen(
        Serializers::Artifact::SCHEMA,
        body: {
          type: "string",
          description: "the body of the version asked for, or of the latest; marked untrusted when an agent wrote it",
        },
        versions: Helpers::Schema.list(Serializers::ArtifactVersion.reference).merge(
          description: "every version, oldest first",
        ),
      ).freeze

      module_function

      def missing_version(id, number) = "artifact #{id} has no version #{number}"
    end
  end
end
