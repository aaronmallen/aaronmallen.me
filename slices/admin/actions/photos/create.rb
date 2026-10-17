# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Photos
      class Create < Action
        CREATED = 201
        REFUSED = 422
        STATUSES = { oversized: REFUSED, unavailable: 503, unreadable: REFUSED }.freeze

        include Deps[upload_photo: "media.operations.upload_photo"]

        config.formats.accept :json

        def handle(request, response)
          case upload_photo.call(Blog::Types::UploadParam[request.params[:photo]])
            in Success(photo)
              answer(response, CREATED, url: settings.site_url(photo.path), key: photo.key)
            in Failure[:invalid, { photo: [code, *] }]
              refuse(response, REFUSED, code)
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
