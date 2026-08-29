# frozen_string_literal: true

module MCP
  module UI
    module Views
      module Authorizations
        class Rejected < View
          def view_template
            header(class: "page-head") do
              div do
                h1(class: "page-head-title") { t(".heading") }
                p(class: "page-head-sub") { t(".message") }
              end
            end
          end
        end
      end
    end
  end
end
