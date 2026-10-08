# frozen_string_literal: true

module MCP
  module UI
    module Views
      module Authorizations
        class New < View
          include Blog::Constants

          APPROVE = Operations::Authorize::APPROVE
          CANCEL = Operations::Authorize::CANCEL
          PUBLISH = Blog::Types::OAuthScope["publish"]

          prop :client_name, Blog::Types::String.optional
          prop :fields, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::String)
          prop :new_client, Blog::Types::Bool
          prop :redirect_uri, Blog::Types::String
          prop :registered_at, Blog::Types::Time
          prop :scopes, Blog::Types::Array.of(Blog::Types::String)

          def view_template
            header(class: "page-head") do
              div do
                h1(class: "page-head-title") { heading }
                p(class: "page-head-sub") { calls_itself }
              end
            end

            render_new_client if @new_client
            render_grants
            render_form
          end

          private

          def calls_itself
            name = @client_name.to_s.strip
            name.empty? ? t(".unnamed") : t(".named", client: name)
          end

          def heading
            host = Blog::Types::Normalized::Host.call(@redirect_uri) { EMPTY_STRING }
            host.empty? ? t(".heading_no_host") : t(".heading", host:)
          end

          def render_form
            Form(action: path(:mcp_oauth_decide), class: "connect-actions") do
              @fields.each { |name, value| input(type: "hidden", name:, value:) }
              button(type: "submit", name: "decision", value: CANCEL, class: "bt") { t(".cancel") }
              button(type: "submit", name: "decision", value: APPROVE, class: "bt pri") { t(".approve") }
            end
          end

          def render_grant(scope)
            li(class: "li") do
              div(class: "li-main") do
                span(class: "li-title") { t(scope_key(scope)) }
                span(class: "connect-warn") { t(".publish_warning") } if scope == PUBLISH
              end
            end
          end

          def render_grants
            section(class: "card") do
              header(class: "card-head") { div { h2(class: "card-title") { t(".grants") } } }

              ul { @scopes.each { render_grant(it) } }

              p(class: "hint") { t(".returns", uri: @redirect_uri) }
            end
          end

          def render_new_client
            p(class: "connect-notice", role: "note") do
              Stamped(text: t(".new_client", time: Stamped::MARK), at: @registered_at)
            end
          end

          def scope_key(scope) = ".scopes.#{scope}"
        end
      end
    end
  end
end
