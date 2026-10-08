# frozen_string_literal: true

module Admin
  module UI
    module Views
      class NotFound < View
        def view_template
          PageHead(title: t(".heading"), sub: t(".message"), kicker: t(".status")) do
            Button(href: path(:admin_root)) { t(".today") }
          end
        end
      end
    end
  end
end
