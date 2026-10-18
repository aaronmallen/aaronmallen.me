# frozen_string_literal: true

module API
  module Endpoints
    class UpdateWebmentionSettings < WebmentionSettingsEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          **TOGGLES.to_h { [it, Helpers::Schema::BOOLEAN] },
          HOSTS => {
            type: "array", items: { type: "string" },
            description: "Hosts that are each one person's site. The list replaces the one stored",
          },
        },
      }.freeze

      include Deps[update_webmention_settings: "social.operations.update_webmention_settings"]

      def handle(**fields)
        case update_webmention_settings.call(**changes(fields))
          in Success(settings) then answered(settings)
          in Failure(:unchanged) then invalid(ROOT => ["nothing saved, since no setting changed"])
          in unmatched then unhandled(unmatched, "could not save the webmention settings")
        end
      end

      private

      def changes(fields)
        found = fields.slice(*FIELDS)
        return found unless found.key?(HOSTS)

        found.merge(HOSTS => Blog::Types::Normalized::Hosts[found[HOSTS]])
      end
    end
  end
end
