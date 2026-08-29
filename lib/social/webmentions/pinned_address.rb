# frozen_string_literal: true

require "faraday"

module Social
  module Webmentions
    class PinnedAddress < Faraday::Adapter::NetHttp
      def build_connection(env)
        super.tap { |http| http.ipaddr = env[:request][:context].to_h[:address] }
      end
    end
  end
end
