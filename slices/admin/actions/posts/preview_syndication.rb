# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class PreviewSyndication < Action
        include Deps[preview_announcement: "operations.preview_announcement"]

        def handle(request, response)
          response.format = :txt
          response.body = preview_announcement.call(Blog::Types::Fields[request.params[:post]])
        end
      end
    end
  end
end
