# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        module Tone
          def self.style(color) = "--tone: var(--color-#{color}-text)"
        end
      end
    end
  end
end
