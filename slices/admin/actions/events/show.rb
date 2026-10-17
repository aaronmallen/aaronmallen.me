# frozen_string_literal: true

module Admin
  module Actions
    module Events
      class Show < Action
        include Deps[hub: "live.hub"]

        config.formats.register(:event_stream, "text/event-stream")
        config.formats.accept :event_stream

        def handle(request, _response)
          hijack = request.env[::Rack::RACK_HIJACK] or halt :not_implemented

          hub.open(hijack.call)
        end

        private

        def require_sign_in(request, _response)
          halt :unauthorized unless auth_session(request).signed_in?
        end
      end
    end
  end
end
