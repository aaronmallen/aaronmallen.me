# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Mail
      class SaveDraft < Action
        include Deps[save_draft: "mail.operations.save_draft"]

        config.formats.accept :html, :json

        def handle(request, response)
          response.format = :json
          case save_draft.call(Blog::Types::Fields[request.params[:mail]])
            in Success(id) then response.body = JSON.generate({ draft: id })
            in Failure[:invalid, _] then halt :unprocessable_content
            in Failure[:gmail_failed, _] then halt :bad_gateway
          end
        end
      end
    end
  end
end
