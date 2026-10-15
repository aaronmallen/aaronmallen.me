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
        TIMING = "timing"
        VIEW = Blog::Types::VisitKind["view"]

        include Deps[
          "operations.find_page",
          check_visit: "analytics.operations.check_visit",
          record_page_timing: "performance.operations.record_page_timing",
          record_visit: "analytics.operations.record_visit",
        ]

        config.formats.clear.accept :json
        config.handle_exception Hanami::Action::BodyParsingError => :reject

        before :refuse_cross_site

        def handle(request, response) = respond(response, status_for(request))

        private

        def checked(visit, route, status)
          return status if status == ACCEPTED || find_page.call(route)

          uncounted(visit)
        end

        def countable?(visit, route)
          return route.params.key?(:slug) if visit["kind"] == CLICK
          return find_page.call(route) if visit["kind"] == VIEW

          true
        end

        def outcome(request, visit)
          record_visit.call(
            visit,
            address: read_visitor_address.call(request),
            base_url: "#{request.scheme}://#{Blog::RequestHost.call(request)}",
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

          status = store(request, visit, route)
          visit["kind"] == VIEW ? status : checked(visit, route, status)
        end

        def store(request, visit, route)
          case outcome(request, visit)
            in Success(counted)
              time(request, visit, route) if counted
              ACCEPTED
            in Failure(Blog::Throttle::THROTTLED) then THROTTLED
            else REJECTED
          end
        end

        def time(request, visit, route)
          return unless visit.key?(TIMING)

          record_page_timing.call(
            visit[TIMING],
            route: route.endpoint.route,
            user_agent: request.get_header("HTTP_USER_AGENT"),
          )
        end

        def uncounted(visit) = check_visit.call(visit).success? ? ACCEPTED : REJECTED
      end
    end
  end
end
