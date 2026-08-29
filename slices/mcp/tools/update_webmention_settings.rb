# frozen_string_literal: true

module MCP
  module Tools
    class UpdateWebmentionSettings < Base
      SCHEMA = {
        additionalProperties: false,
        properties: WebmentionSettingsAnswer::FIELDS.to_h { [it, { type: "boolean" }] },
      }.freeze

      description "Change the webmention settings. A setting you leave out keeps what it has. " \
                  "A call that changes nothing saves nothing and says so"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        include WebmentionSettingsAnswer

        def call(server_context:, **fields)
          case update_webmention_settings(server_context).call(**fields.slice(*FIELDS))
          in Success(settings) then answer(settings_entry(settings))
          in Failure(:unchanged) then refuse("nothing saved, since no setting changed")
          else refuse("could not save the webmention settings")
          end
        end
      end
    end
  end
end
