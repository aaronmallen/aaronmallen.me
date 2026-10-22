# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class Edited < Component
          prop :at, Blog::Types::Time

          def view_template
            local = Blog::TimeZone.local(@at)
            today = local.to_date == Blog::TimeZone.today

            Moment(at: @at) { today ? t(".today", time: l(local, format: :clock)) : l(local.to_date, format: :short) }
          end
        end
      end
    end
  end
end
