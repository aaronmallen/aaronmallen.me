# frozen_string_literal: true

module API
  module Structs
    class OAuthClient < Blog::DB::Struct
      def display_name
        [client_name, redirect_host].map { it.to_s.strip }.find { !it.empty? } || client_id
      end

      def redirect_host = Blog::Types::Normalized::Host.call(redirect_uris.first) { nil }
    end
  end
end
