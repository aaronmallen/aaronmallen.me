# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Photos
      class Create < Action
        CREATED = 201
        MESSAGES = {
          "blank" => "photo_upload.errors.blank",
          "large" => "photo_upload.errors.large",
          "type" => "photo_upload.errors.type",
          oversized: "photo_upload.errors.oversized",
          unavailable: "photo_upload.errors.unavailable",
          unreadable: "photo_upload.errors.unreadable",
        }.freeze
        REFUSED = 422
        STATUSES = { oversized: REFUSED, unavailable: 503, unreadable: REFUSED }.freeze

        include Deps[upload_photo: "media.operations.upload_photo"]

        config.formats.accept :json

        def handle(request, response)
          case upload_photo.call(Blog::Types::UploadParam[request.params[:photo]])
            in Success(photo)
              answer(response, CREATED, url: photo.url)
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

        def refuse(response, status, code) = answer(response, status, error: i18n.t(MESSAGES.fetch(code)))
      end
    end
  end
end
