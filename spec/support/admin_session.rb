# frozen_string_literal: true

require "rack/session/encryptor"
require "rack/utils"
require "securerandom"

module Spec
  module AdminSession
    CSRF_TOKEN = Hanami::Action::CSRFProtection::CSRF_TOKEN.to_s
    EMAIL = "owner@example.com"

    module_function

    def cookie(csrf_token: new_csrf_token)
      Rack::Utils.escape(encryptor.encrypt(session(csrf_token)))
    end

    def encryptor
      options = Admin::Slice.config.actions.sessions.options.first

      Rack::Session::Encryptor.new(
        Array(options.fetch(:secrets)).first,
        purpose: options.fetch(:key),
        serialize_json: options.fetch(:serialize_json),
      )
    end

    def new_csrf_token = SecureRandom.hex(32)

    def session(csrf_token)
      {
        CSRF_TOKEN => csrf_token,
        "email" => EMAIL,
        "session_id" => SecureRandom.hex(16),
        "signed_in_at" => Time.now.to_i,
      }
    end
  end
end

RSpec.configure do |config|
  config.before { Admin::Slice["repos.owner_identity_mutations"].add(Spec::AdminSession::EMAIL) }
end
