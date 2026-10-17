# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class WebmentionSettingsEndpoint < Endpoint
      HOSTS = :single_author_hosts
      TOGGLES = ::Social::Operations::UpdateWebmentionSettings::TOGGLES
      FIELDS = [*TOGGLES, HOSTS].freeze

      REPLY = Helpers::Schema.object(
        { **TOGGLES.to_h { [it, Helpers::Schema::BOOLEAN] }, HOSTS => Helpers::Schema.list(Helpers::Schema::STRING) },
      ).freeze

      private

      def answered(settings) = Success(settings.to_h.slice(*TOGGLES).merge(HOSTS => settings.public_send(HOSTS).to_a))
    end
  end
end
