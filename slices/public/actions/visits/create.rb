# frozen_string_literal: true

require "json"
require "uri"

module Public
  module Actions
    module Visits
      class Create < Action
        ACCEPTED = 202
        CLICK = Blog::Types::VisitKind["click"]
        MAX_BYTES = 8192
        PLAIN_PATH = %r{\A/(?!/)[^?#]*\z}
        REJECTED = 400
        THROTTLED = 429

        include Deps[
          "operations.find_page",
          "operations.find_visitor_address",
          record_visit: "analytics.operations.record_visit",
          visit_contract: "analytics.contracts.visit_contract",
        ]

        config.formats.clear.accept :json
        config.handle_exception Hanami::Action::BodyParsingError => :reject

        before :refuse_cross_site

        def handle(request, response) = respond(response, status_for(request))

        private

        def countable?(visit, route)
          return false if visit["kind"] == CLICK && !route.params.key?(:slug)

          find_page.call(route)
        end

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

        def route_for(visit)
          path = visit["path"].to_s if visit.is_a?(Hash)
          return unless path && PLAIN_PATH.match?(path)

          route = Slice.router.recognize(path)
          route if route.routable?
        rescue URI::Error
          nil
        end

        def signed_in?(request) = session_reader.call(request).signed_in?

        def status_for(request)
          visit = payload(request)
          route = route_for(visit)
          return REJECTED unless route
          return uncounted(visit) unless countable?(visit, route)

          case outcome(request, visit)
          in Success(_) then ACCEPTED
          in Failure(:throttled) then THROTTLED
          else REJECTED
          end
        end

        def uncounted(visit) = visit_contract.call(visit).success? ? ACCEPTED : REJECTED
      end
    end
  end
end
