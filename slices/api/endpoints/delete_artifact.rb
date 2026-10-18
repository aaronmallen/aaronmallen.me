# frozen_string_literal: true

module API
  module Endpoints
    class DeleteArtifact < ArtifactEndpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, deleted: Helpers::Schema::BOOLEAN }).freeze

      include Deps[delete_artifact: "agents.operations.delete_artifact"]

      def handle(id:) = settled(delete_artifact.call(id), id) { { id:, deleted: true } }
    end
  end
end
