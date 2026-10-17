# frozen_string_literal: true

require "uri"

module Public
  module Actions
    module Visits
      class Create < Action
        CLICK = Blog::Types::VisitKind["click"]
        MALFORMED = :malformed
        MAX_BYTES = 8192
        PLAIN_PATH = %r{\A/(?!/)[^?#]*\z}
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
        before :refuse_oversized

        def handle(request, response) = respond(response, status_for(request))

        private

        def follow_up(request, visit, route)
          result = outcome(request, visit)
          return :accepted if result.failure? && result.failure != MALFORMED && !find_page.call(route)

          store(request, visit, route, result)
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

        def refuse_oversized(request, _response)
          halt :bad_request, Blog::Constants::EMPTY_STRING if request.content_length.to_i > MAX_BYTES
        end

        def reject(_request, response, _exception) = respond(response, :bad_request)

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
          visit = request.env[ACTION_PARSED_BODY]
          route = route_for(visit)
          return :bad_request unless route

          case visit["kind"]
            in VIEW then find_page.call(route) ? store(request, visit, route) : uncounted(visit)
            in CLICK unless route.params.key?(:slug) then uncounted(visit)
            else follow_up(request, visit, route)
          end
        end

        def store(request, visit, route, result = outcome(request, visit))
          case result
            in Success(counted)
              time(request, visit, route) if counted
              :accepted
            in Failure(Blog::Throttle::THROTTLED) then :too_many_requests
            else :bad_request
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

        def uncounted(visit) = check_visit.call(visit).success? ? :accepted : :bad_request
      end
    end
  end
end
