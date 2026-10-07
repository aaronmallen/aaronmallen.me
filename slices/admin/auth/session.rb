# auto_register: false
# frozen_string_literal: true

require "rack/utils"
require "securerandom"
require "uri"

module Admin
  module Auth
    class Session
      LOCAL_PATH = %r{\A/(?![/\\])[^\\[:space:][:cntrl:]]*\z}
      REQUEST_KEY = "admin.auth.session"
      SIGN_IN_LIMIT = 5

      include Deps["routes", "settings", "repos.session_validity_queries"]

      def self.for(request) = request.env[REQUEST_KEY] ||= new(request.session)

      def initialize(session, now: Time.now, **)
        super(**)
        @now = now.to_i
        @session = session
      end

      def admin_return_path(wanted)
        path = local_path(wanted)
        wanted if path && admin_path?(path)
      end

      def csrf_token
        @session[Hanami::Action::CSRFProtection::CSRF_TOKEN.to_s]
      end

      def return_to
        @session["return_to"]
      end

      def return_to=(path)
        @session["return_to"] = path
      end

      def sign_in(github_user_id)
        path = return_to
        @session.clear
        @session.options[:renew] = true
        @session["github_user_id"] = github_user_id
        @session["signed_in_at"] = @now
        path
      end

      def sign_out(wanted = nil)
        path = return_path(wanted)
        @session.clear
        @session.options[:drop] = true
        path
      end

      def signed_in?
        settings.operator?(@session["github_user_id"]) && !expired? && !ended?
      end

      def start_sign_in
        state = SecureRandom.urlsafe_base64(32)
        @session["oauth_states"] = oauth_states.push(state).last(SIGN_IN_LIMIT)
        state
      end

      def state?(state)
        return false unless state.is_a?(String)

        started = oauth_states
        matched = started.find { it.is_a?(String) && Rack::Utils.secure_compare(it, state) }
        return false if matched.nil?

        @session["oauth_states"] = started - [matched]
        true
      end

      private

      def admin_path?(path)
        admin_root = routes.path(:admin_root)
        path == admin_root || path.start_with?("#{admin_root}/")
      end

      def ended?
        return false if valid_after.nil?

        @session["signed_in_at"] <= valid_after.to_i
      end

      def expired?
        signed_in_at = @session["signed_in_at"]
        !signed_in_at.is_a?(Integer) || @now - signed_in_at >= Blog::SessionCookie::LIFETIME
      end

      def local_path(wanted)
        return unless wanted.is_a?(String) && LOCAL_PATH.match?(wanted)

        URI.parse(wanted).path
      rescue URI::InvalidURIError
        nil
      end

      def oauth_states
        started = @session["oauth_states"]
        started.is_a?(Array) ? started.dup : []
      end

      def return_path(wanted)
        path = local_path(wanted)
        wanted if path && !admin_path?(path)
      end

      def valid_after
        @valid_after = session_validity_queries.valid_after unless defined?(@valid_after)
        @valid_after
      end
    end
  end
end
