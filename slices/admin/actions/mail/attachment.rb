# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Attachment < Action
        OCTET_STREAM = "application/octet-stream"
        UNSAFE_FILENAME = /[^\w.\- ]/

        include Deps[download_attachment: "mail.operations.download_attachment"]

        def handle(request, response)
          case download_attachment.call(record_id(request), request.params[:part])
            in Success[attachment, data] then serve(response, attachment, data)
            in Failure(:not_found) then halt :not_found
            in Failure[:gmail_failed, _] then halt :bad_gateway
          end
        end

        private

        def disposition(name)
          "attachment; filename=\"#{name.gsub(UNSAFE_FILENAME, '_')}\"; filename*=UTF-8''#{ERB::Util.url_encode(name)}"
        end

        def serve(response, attachment, data)
          response.headers.merge!(
            "content-disposition" => disposition(attachment.filename), "content-type" => OCTET_STREAM,
            "x-content-type-options" => "nosniff",
          )
          response.body = data
        end
      end
    end
  end
end
