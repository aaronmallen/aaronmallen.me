# frozen_string_literal: true

require "base64"
require "digest"

module MCP
  module Operations
    class DeriveCodeChallenge
      def call(verifier) = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    end
  end
end
