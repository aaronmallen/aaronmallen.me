# frozen_string_literal: true

require "base64"
require "digest"
require "rack/utils"

module MCP
  module OAuth
    module PKCE
      METHOD = "S256"
      SHAPE = /\A[A-Za-z0-9\-._~]{43,128}\z/

      module_function

      def challenge(verifier) = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)

      def matches?(stored, verifier) = Rack::Utils.secure_compare(stored, challenge(verifier))
    end
  end
end
