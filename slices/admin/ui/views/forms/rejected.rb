# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Forms
        class Rejected < View
          def view_template
            PageHead(title: t(".heading"), sub: t(".message"))
          end
        end
      end
    end
  end
end
