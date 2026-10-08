# frozen_string_literal: true

module API
  module Serializers
    class Project < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          name: Helpers::Schema::STRING,
          tagline: Helpers::Schema.nullable(Helpers::Schema::STRING),
          status: { type: "string", enum: %w[active archived], description: "archived once it has an archive date" },
          visibility: { type: "string", enum: Blog::Types::ProjectVisibility.values },
          started_on: Helpers::Schema.nullable(Helpers::Schema::DAY),
          archived_on: Helpers::Schema.nullable(Helpers::Schema::DAY),
          tags: Helpers::Schema::TAGS,
          repo: Helpers::Schema.nullable({ type: "string", description: "the repository, as owner/name" }),
          url: Helpers::Schema.nullable(Helpers::Schema::STRING),
          og_image_url: Helpers::Schema.nullable(Helpers::Schema::STRING),
          stars: Helpers::Schema::INTEGER,
          release: Helpers::Schema.nullable({ type: "string", description: "the latest release" }),
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
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
