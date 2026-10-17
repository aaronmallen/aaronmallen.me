# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Send < Index
        ARCHIVED = "mail_page.toasts.sent_archived"
        GMAIL_FAILED = { send: ["gmail"] }.freeze
        SENT = "mail_page.toasts.sent"

        include Redirect
        include Deps[index_view: "ui.views.mail.index"]

        def handle(request, response)
          fields = Blog::Types::Fields[request.params[:mail]]

          case send_mail.call(fields)
            in Success(_) then sent(request, response, fields)
            in Failure[:invalid, errors] then retry_draft(request, response, fields, errors)
            in Failure[:gmail_failed, _] then retry_draft(request, response, fields, GMAIL_FAILED)
            in Failure(:not_found) then halt :not_found
            else halt :internal_server_error
          end
        end

        private

        def retry_draft(request, response, fields, errors)
          show(request, response, draft: { values: fields, errors: })
          unprocessable(response, index_view)
        end

        def sent(request, response, fields)
          archived = Blog::Types::Checkbox[fields[:archive]]
          thread = Blog::Types::IdParam[fields[:thread]] unless archived

          toast(response, archived ? ARCHIVED : SENT)
          response.redirect_to(listed(request, thread:))
        end
      end
    end
  end
end
