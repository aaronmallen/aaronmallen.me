# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Sessions
        class Failed < View
          MESSAGES = {
            denied: ".denied",
            github_failed: ".github_failed",
            not_configured: ".not_configured",
            wrong_account: ".wrong_account",
          }.freeze
          UNEXPECTED = ".unexpected"

          def initialize(reason:)
            super()
            @reason = reason
          end

          def view_template
            PageHead(title: t(".heading"), sub: t(MESSAGES.fetch(@reason, UNEXPECTED)))
          end
        end
      end
    end
  end
end
