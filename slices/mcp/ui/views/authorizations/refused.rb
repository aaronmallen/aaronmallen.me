# frozen_string_literal: true

module MCP
  module UI
    module Views
      module Authorizations
        class Refused < View
          def initialize(error:, error_description:, url:)
            super()
            @error = error
            @error_description = error_description
            @url = url
          end

          def view_template
            header(class: "page-head") do
              div do
                h1(class: "page-head-title") { t(".heading") }
                p(class: "page-head-sub") { t(".message", host:) }
              end
            end

            render_error
          end

          private

          def host = Blog::Types::Normalized::Host.call(@url) { @url }

          def render_error
            section(class: "card") do
              p { t(".error", description: @error_description, error: @error) }
              p(class: "hint") { t(".nothing") }
              a(class: "btn", href: @url) { t(".back", host:) }
            end
          end
        end
      end
    end
  end
end
