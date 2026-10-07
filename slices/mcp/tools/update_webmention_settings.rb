# frozen_string_literal: true

module MCP
  module Tools
    class UpdateWebmentionSettings < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          **WebmentionSettingsAnswer::TOGGLES.to_h { [it, { type: "boolean" }] },
          WebmentionSettingsAnswer::HOSTS => {
            type: "array", items: { type: "string" },
            description: "Hosts that are each one person's site. The list replaces the one stored",
          },
        },
      }.freeze

      description "Change the webmention settings. A setting you leave out keeps what it has. " \
                  "A call that changes nothing saves nothing and says so"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        include WebmentionSettingsAnswer

        def call(server_context:, **fields)
          case dep(:update_webmention_settings, server_context).call(**changes(fields))
            in Success(settings) then answer(settings_entry(settings))
            in Failure(:unchanged) then refuse("nothing saved, since no setting changed")
            else refuse("could not save the webmention settings")
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
end
