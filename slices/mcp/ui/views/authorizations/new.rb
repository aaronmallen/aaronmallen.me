# frozen_string_literal: true

module MCP
  module UI
    module Views
      module Authorizations
        class New < View
          include Dry::Core::Constants

          APPROVE = Operations::Authorize::APPROVE
          CANCEL = Operations::Authorize::CANCEL

          def initialize(client_name:, fields:, redirect_uri:, scopes:)
            super()
            @client_name = client_name
            @fields = fields
            @redirect_uri = redirect_uri
            @scopes = scopes
          end

          def view_template
            header(class: "page-head") do
              div do
                h1(class: "page-head-title") { t(".heading") }
                p(class: "page-head-sub") { asking }
              end
            end

            render_grants
            render_form
          end

          private

          def asking
            name = client
            name.empty? ? t(".asking_unnamed") : t(".asking", client: name)
          end

          def client
            name = @client_name.to_s.strip
            name.empty? ? Blog::Types::Normalized::Host.call(@redirect_uri) { EMPTY_STRING } : name
          end

          def render_form
            Form(action: path(:mcp_oauth_decide), class: "connect-actions") do
              @fields.each { |name, value| input(type: "hidden", name:, value:) }
              button(type: "submit", name: "decision", value: CANCEL, class: "btn") { t(".cancel") }
              button(type: "submit", name: "decision", value: APPROVE, class: "btn pri") { t(".approve") }
            end
          end

          def render_grants
            section(class: "card") do
              header(class: "card-head") { div { h2(class: "card-title") { t(".grants") } } }

              ul do
                @scopes.each { |scope| li(class: "li") { span(class: "li-title") { t(scope_key(scope)) } } }
              end

              p(class: "hint") { t(".returns", uri: @redirect_uri) }
            end
          end

          def scope_key(scope) = ".scopes.#{scope}"
        end
      end
    end
  end
end
