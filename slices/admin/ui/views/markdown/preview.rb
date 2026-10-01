# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Markdown
        class Preview < View
          layout nil

          def initialize(html:)
            super()
            @html = html
          end

          def view_template
            div(class: "post-body") { raw(safe(@html)) }
          end
        end
      end
    end
  end
end
