# frozen_string_literal: true

module Public
  module UI
    module Profiles
      module_function

      def call(*networks)
        networks
          .to_h { [it, Hanami.app.settings.public_send(it)[:profile_url]] }
          .select { |_, url| Blog::Types::Url.valid?(url) }
      end
    end
  end
end
