# frozen_string_literal: true

module API
  module Serializers
    class ShareGroup < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          code: { type: "string", description: "the group's short code on the share host" },
          url: { type: "string", description: "the link that opens the group's page" },
          view_count: Helpers::Schema::INTEGER,
          zip_download_count: Helpers::Schema::INTEGER,
          files: Helpers::Schema.list(ShareGroupFile.reference),
          created_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at

      def files(group)
        ShareGroupFile.new(group.share_group_files, params: params.merge(code: group.code)).serializable_hash
      end

      def url(group) = "#{params.fetch(:origin)}/#{group.code}"
    end
  end
end
