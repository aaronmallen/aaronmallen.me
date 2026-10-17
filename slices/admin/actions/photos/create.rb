# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Photos
      class Create < Action
        STATUSES = {
          oversized: :unprocessable_content,
          unavailable: :service_unavailable,
          unreadable: :unprocessable_content,
        }.freeze

        include Deps[upload_photo: "media.operations.upload_photo"]

        config.formats.accept :json

        def handle(request, response)
          case upload_photo.call(Blog::Types::UploadParam[request.params[:photo]])
            in Success(photo)
              answer(response, :created, url: settings.site_url(photo.path), key: photo.key)
            in Failure[:invalid, { photo: [code, *] }]
              refuse(response, :unprocessable_content, code)
            in Failure[reason]
              refuse(response, STATUSES.fetch(reason), reason)
          end
        end

        private

        def answer(response, status, **body)
          response.status = status
          response.format = :json
          response.body = JSON.generate(body)
        end

        def refuse(response, status, code)
          error = i18n.t(code, scope: "photo_upload.errors", **::Media::Operations::UploadPhoto::LIMITS)

          answer(response, status, error:)
        end
      end
    end
  end
end
