# frozen_string_literal: true

module MCP
  module Tools
    module WebmentionSettingsAnswer
      FIELDS = %i[accept_bridgy auto_approve_known_authors enable_on_new_posts receive send_on_publish].freeze

      private

      def settings_entry(settings) = settings.to_h.slice(*FIELDS)
    end
  end
end
