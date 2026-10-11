# frozen_string_literal: true

module Public
  module UI
    module Profiles
      module_function

      def call(settings, *networks)
        networks
          .to_h { [it, settings.public_send(it)[:profile_url]] }
          .select { |_, url| Blog::Types::Url.valid?(url) }
      end
    end
  end
end
