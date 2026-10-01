# frozen_string_literal: true

module Public
  module Actions
    module Webmentions
      class Create < Action
        ACCEPTED = 202
        REJECTED = 400
        THROTTLED = 429

        include Deps[
          "operations.find_visitor_address",
          hash_visitor: "analytics.operations.hash_visitor",
          receive_webmention: "social.operations.receive_webmention",
        ]

        answer_any_accept

        def handle(request, response)
          outcome = receive_webmention.call(
            source: request.params[:source], target: request.params[:target], visitor_hash: visitor_hash(request),
          )

          response.status = status_for(outcome)
          response.body = Blog::Constants::EMPTY_STRING
        end

        private

        def status_for(outcome)
          case outcome
          in Success(_) then ACCEPTED
          in Failure(:throttled) then THROTTLED
          else REJECTED
          end
        end

        def visitor_hash(request) = hash_visitor.call(address: find_visitor_address.call(request))
      end
    end
  end
end
