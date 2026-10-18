# frozen_string_literal: true

module API
  module Serializers
    class LoadedMemoryFile < Serializer
      SCHEMA = Helpers::Schema.object(
        MemoryFile::SCHEMA.fetch(:properties).slice(:id, :path, :scope, :repo, :project_id, :task_id),
      ).freeze

      schema_attributes
    end
  end
end
