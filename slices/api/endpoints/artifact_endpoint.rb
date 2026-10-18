# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class ArtifactEndpoint < Endpoint
      REPLY = Artifacts::REPLY

      include Deps[artifact_queries: "agents.repos.artifact_queries"]

      private

      def replied(artifact, number = artifact.version)
        shown = artifact_queries.version(artifact.id, number)

        serialized(Serializers::Artifact, artifact).merge(
          body: shown.agent? ? untrusted(shown.body) : shown.body,
          versions: serialized(Serializers::ArtifactVersion, artifact_queries.versions(artifact.id)),
        )
      end

      def settled(result, id, missing: Helpers::Wording.missing("artifact", id))
        case result
          in Success(value) then Success(yield(value))
          in Failure(:not_found) then not_found(missing)
          in Failure[:invalid, errors] then rejected(errors, Artifacts::COMPLAINTS)
          in unmatched then unhandled(unmatched, Helpers::Wording::UNSAVED)
        end
      end

      def untrusted(text) = Helpers::Untrusted.call(text)
    end
  end
end
