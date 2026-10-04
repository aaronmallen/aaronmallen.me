# frozen_string_literal: true

module MCP
  module Tools
    module WebmentionSettingsAnswer
      HOSTS = :single_author_hosts
      TOGGLES = %i[accept_bridgy auto_approve_known_authors enable_on_new_posts receive send_on_publish].freeze
      FIELDS = [*TOGGLES, HOSTS].freeze

      private

      def settings_entry(settings) = settings.to_h.slice(*TOGGLES).merge(HOSTS => settings.public_send(HOSTS).to_a)
    end
  end
end
