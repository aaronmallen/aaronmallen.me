# frozen_string_literal: true

module Admin
  module Actions
    module Social
      class UnlinkRecord < Action
        KIND = Blog::Types::RecordKind["social_post"]

        include RecordLinking
        include Deps[unlink_records: "links.operations.unlink_records"]

        def handle(request, response) = unlink(request, response)

        private

        def record_path(request, id)
          routes.path(:admin_social, filter: Blog::Types::SocialQueueParam[request.params[:filter]], edit: id)
        end
      end
    end
  end
end
