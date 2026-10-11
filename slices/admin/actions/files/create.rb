# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Files
      class Create < Action
        CREATED = 201
        JSON_TYPE = "application/json"
        REFUSED = 422
        STATUSES = { blank: REFUSED, invalid: REFUSED, unavailable: 503 }.freeze
        TOASTS = {
          nil => "files_page.toasts.uploaded",
          blank: "files_page.toasts.failed.blank",
          invalid: "files_page.toasts.failed.invalid",
          unavailable: "files_page.toasts.failed.unavailable",
        }.freeze

        include Deps[upload_share: "shares.operations.upload_share"]

        config.formats.accept :html, :json

        def handle(request, response)
          links, reason = upload(Array(request.params[:files]).select { it.is_a?(::Hash) && it[:tempfile] })
          return answer(response, links, reason) if json?(request)

          toast(response, TOASTS.fetch(reason), count: links.size)
          response.redirect_to(routes.path(:admin_files))
        end

        private

        def answer(response, links, reason)
          response.status = reason ? STATUSES.fetch(reason) : CREATED
          response.format = :json
          response.body = JSON.generate({ links:, message: i18n.t!(TOASTS.fetch(reason), count: links.size) })
        end

        def json?(request) = request.get_header("HTTP_ACCEPT").to_s.start_with?(JSON_TYPE)

        def upload(files)
          return [[], :blank] if files.empty?

          links = []
          files.each do |file|
            case upload_share.call(file)
              in Success(share) then links << Helpers::ShareLink.for(share.code)
              in Failure[reason, *] then return [links, reason]
            end
          end
          [links, nil]
        end
      end
    end
  end
end
