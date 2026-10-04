# frozen_string_literal: true

require "digest"

module Analytics
  module Operations
    class HashReader
      include Deps["settings"]

      def call(address:, user_agent:, path:)
        parts = [settings.reader_salt, path, address, user_agent]

        Digest::SHA256.hexdigest(parts.join(HashVisitor::SEPARATOR))
      end
    end
  end
end
