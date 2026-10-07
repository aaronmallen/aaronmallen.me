# frozen_string_literal: true

module API
  module Serializers
    class Project < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          name: Schema::STRING,
          tagline: Schema.nullable(Schema::STRING),
          status: { type: "string", enum: %w[active archived], description: "archived once it has an archive date" },
          visibility: { type: "string", enum: Blog::Types::ProjectVisibility.values },
          started_on: Schema.nullable(Schema::DAY),
          archived_on: Schema.nullable(Schema::DAY),
          tags: Schema::TAGS,
          repo: Schema.nullable({ type: "string", description: "the repository, as owner/name" }),
          url: Schema.nullable(Schema::STRING),
          og_image_url: Schema.nullable(Schema::STRING),
          stars: Schema::INTEGER,
          release: Schema.nullable({ type: "string", description: "the latest release" }),
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at
      tag_names

      def archived_on(project) = day(project.archived_on)

      def started_on(project) = day(project.started_on)
    end
  end
end
