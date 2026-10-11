# frozen_string_literal: true

module Admin
  module Actions
    module Social
      class UnlinkRecord < UnlinkRecordAction
        KIND = Blog::Types::RecordKind["social_post"]

        private

        def record_path(request, id)
          routes.path(:admin_social, filter: Blog::Types::SocialQueueParam[request.params[:filter]], edit: id)
        end
      end
    end
  end
end
