# frozen_string_literal: true

require "json"
require "uri"

module Public
  module Actions
    module Visits
      class Create < Action
        ACCEPTED = 202
        MAX_BYTES = 8192
        PLAIN_PATH = %r{\A/(?!/)[^?#]*\z}
        REJECTED = 400
        THROTTLED = 429

        include Deps[
          "operations.find_visitor_address",
          record_visit: "analytics.operations.record_visit",
        ]

        config.formats.clear.accept :json
        config.handle_exception Hanami::Action::BodyParsingError => :reject

        before :refuse_cross_site

        def handle(request, response) = respond(response, status_for(request))

        private

        def outcome(request, visit)
          record_visit.call(
            visit,
            address: find_visitor_address.call(request),
            base_url: request.base_url,
            signed_in: signed_in?(request),
            user_agent: request.get_header("HTTP_USER_AGENT"),
          )
        end

        def payload(request)
          JSON.parse(request.body.read(MAX_BYTES).to_s)
        rescue JSON::ParserError
          nil
        end

        def reject(_request, response, _exception) = respond(response, REJECTED)

        def respond(response, status)
          response.status = status
          response.body = Blog::Constants::EMPTY_STRING
        end

        def routable?(visit) = visit.is_a?(Hash) && routable_path?(visit["path"].to_s)

        def routable_path?(path)
          PLAIN_PATH.match?(path) && Slice.router.recognize(path).routable?
        rescue URI::Error
          false
        end

        def signed_in?(request) = session_reader.call(request).signed_in?

        def status_for(request)
          visit = payload(request)
          return REJECTED unless routable?(visit)

          case outcome(request, visit)
          in Success(_) then ACCEPTED
          in Failure(:throttled) then THROTTLED
          else REJECTED
          end
        end
      end
    end
  end
end
