# frozen_string_literal: true

module Public
  module Actions
    module Messages
      class Create < Action
        HONEYPOT = UI::Views::Pages::Contact::HONEYPOT
        REJECTED = 422
        SENT = Pages::Contact::SENT
        STAMP = UI::Views::Pages::Contact::STAMP
        THROTTLED = 429

        include Deps[
          check_stamp: "operations.check_contact_stamp",
          contact_view: "ui.views.pages.contact",
          create_message: "contact.operations.create_message",
          hash_visitor: "analytics.operations.hash_visitor",
          issue_stamp: "operations.issue_contact_stamp",
        ]

        answer_any_accept

        before :refuse_cross_site

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:message]]
          return confirm(response) if baited?(params) || !check_stamp.call(params[STAMP])

          case create_message.call(params, visitor_hash: visitor_hash(request))
            in Success(_) then confirm(response)
            in Failure[:throttled] then refuse(response)
            in Failure[:invalid, errors] then reject(response, params, errors)
          end
        end

        private

        def baited?(params) = !params[HONEYPOT].to_s.strip.empty?

        def confirm(response) = response.redirect_to(routes.path(:contact, sent: SENT))

        def refuse(response)
          response.status = THROTTLED
          response.render(contact_view, throttled: true)
        end

        def reject(response, params, errors)
          response.status = REJECTED
          response.render(contact_view, errors:, values: values(params))
        end

        def values(params)
          %i[body reply_to subject].to_h { [it, params[it].to_s] }.merge(STAMP => issue_stamp.call)
        end

        def visitor_hash(request)
          hash_visitor.call(address: Blog::Types::ThrottleKey[read_visitor_address.call(request)])
        end
      end
    end
  end
end
