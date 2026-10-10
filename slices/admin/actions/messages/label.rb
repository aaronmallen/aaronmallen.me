# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Label < Action
        CLEARED = "messages_page.toasts.labels_cleared"
        INVALID = "messages_page.toasts.labels_invalid"
        SAVED = "messages_page.toasts.labels_saved"

        include Deps[label_message: "contact.operations.label_message"]

        def handle(request, response)
          id = record_id(request)
          back = back(request, id)

          case label_message.call(id, tags(request))
            in Failure[:invalid, _] then refuse(response, back)
            in Success([]) => result then settle(response, result, CLEARED, back)
            in result then settle(response, result, SAVED, back)
          end
        end

        private

        def back(request, id)
          Helpers::MessageList.back(routes, Helpers::MessageList.from(request.params, :filter), open: id)
        end

        def refuse(response, back)
          toast(response, INVALID)
          response.redirect_to(back)
        end

        def tags(request) = [*request.params[:tags], request.params[:name]].join(",")
      end
    end
  end
end
