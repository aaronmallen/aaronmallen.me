# frozen_string_literal: true

module MCP
  module UI
    module Views
      module Authorizations
        class Rejected < View
          def view_template
            PageHead(title: t(".heading"), sub: t(".message"))
          end
        end
      end
    end
  end
end
