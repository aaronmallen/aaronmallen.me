# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Sessions
        class Failed < View
          MESSAGES = {
            denied: ".denied",
            not_configured: ".not_configured",
            provider_failed: ".provider_failed",
            wrong_account: ".wrong_account",
          }.freeze
          NAMES = { github: "GitHub", google: "Google" }.freeze
          UNEXPECTED = ".unexpected"

          prop :reason, Blog::Types::Symbol
          prop :provider, Blog::Types::Symbol.enum(*NAMES.keys)

          def view_template
            PageHead(title: t(".heading"), sub: t(MESSAGES.fetch(@reason, UNEXPECTED), name: NAMES.fetch(@provider)))
          end
        end
      end
    end
  end
end
