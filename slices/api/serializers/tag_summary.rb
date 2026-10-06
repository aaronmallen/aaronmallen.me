# frozen_string_literal: true

module API
  module Serializers
    class TagSummary < Serializer
      KINDS = { posts: Post, projects: Project, tasks: Task, journal_entries: JournalEntry, decisions: Decision }.freeze

      SCHEMA = Schema.object(
        { name: Schema::STRING, **KINDS.transform_values { Schema.list(it.reference) } },
      ).freeze

      schema_attributes

      KINDS.each do |kind, serializer|
        define_method(kind) { |summary| serializer.new(summary.public_send(kind)).serializable_hash }
      end
    end
  end
end
