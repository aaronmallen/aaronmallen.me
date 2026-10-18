# frozen_string_literal: true

module Agents
  module Relations
    class ArtifactVersions < Blog::DB::Relation
      LISTED = %i[id artifact_id number note agent model session_id created_at].freeze
      WRITES = %i[id artifact_id number].freeze

      schema :artifact_versions, infer: true

      def current = join(:artifacts, id: :artifact_id, version: :number)

      def listed = select(*LISTED).order(self[:number].asc)

      def session_listed = select(:id, :artifact_id, :number, :session_id).order(self[:id].asc)

      def session_writes
        join(:artifacts, id: self[:artifact_id].qualified)
          .select(*WRITES.map { self[it].qualified }, artifacts[:title].qualified)
          .order(self[:id].qualified.asc)
      end
    end
  end
end
