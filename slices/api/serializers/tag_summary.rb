# frozen_string_literal: true

module API
  module Serializers
    class TagSummary < Serializer
      KINDS = { posts: Post, projects: Project, tasks: Task, journal_entries: JournalEntry, decisions: Decision }.freeze
      SCOPES = Blog::Types::TagScope.values

      DESCRIPTION = Helpers::Schema.nullable(Helpers::Schema::STRING)
      DESCRIPTIONS = Helpers::Schema.object(SCOPES.to_h { [it.to_sym, DESCRIPTION] })
                                    .merge(description: "each scope's markdown description of the tag, or null")
                                    .freeze

      SCHEMA = Helpers::Schema.object(
        {
          name: Helpers::Schema::STRING,
          descriptions: DESCRIPTIONS,
          **KINDS.transform_values { Helpers::Schema.list(it.reference) },
        },
      ).freeze

      schema_attributes

      def descriptions(summary) = SCOPES.to_h { [it, summary.tag(it)&.description] }

      KINDS.each do |kind, serializer|
        define_method(kind) { |summary| serializer.new(summary.public_send(kind)).serializable_hash }
      end
    end
  end
end
