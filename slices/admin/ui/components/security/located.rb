# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Security
        module Located
          SCOPE = "ui.components.security"

          private

          def device(record) = known(dotted(record.browser, record.os), :unknown_device)

          def known(text, key) = text.empty? ? t([SCOPE, key].join(".")) : text

          def place(record) = known(dotted(record.city, record.country_name || record.country), :unknown_place)
        end
      end
    end
  end
end
