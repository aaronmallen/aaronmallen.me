# frozen_string_literal: true

module Blog
  module RequestHost
    PORT = /:\d+\z/

    def self.call(request) = (request.host_authority || request.server_name).to_s.sub(PORT, "")
  end
end
