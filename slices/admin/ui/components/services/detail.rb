# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Detail < Component
          CLOSE_ICON = "fa-solid fa-xmark"

          prop :row, Blog::Types::Instance(Structs::ServiceRow)
          prop :connectable, Blog::Types::Bool

          def view_template
            head
            p(class: "svc-status") do
              StatusPill(status: @row.status)
              span(class: "svc-account") { @row.account } if @row.account
            end
            powers
            access if definition.oauth? && @row.connection
            credentials
            jobs
            Actions(row: @row, connectable: @connectable)
          end

          private

          def access
            label(t(".access"))
            way if definition.credentials?
            definition.scopes.each { scope(it) } unless by_token? && @row.connection.scopes.empty?
            Hint { Stamped(text: t(".connected", time: Stamped::MARK), at: @row.connection.created_at) }
          end

          def by_token? = @row.connection.by_credentials?

          def close = { href: path(:admin_services), aria: { label: t(".close") } }

          def credentials
            return no_credentials if @row.env.empty?

            label(t(definition.oauth? ? ".app_credentials" : ".credentials"))
            @row.env.each { |name, set| line(name) { held(set, nil, ".set", ".missing") } }
            Hint { t(".environment") }
          end

          def definition = @row.definition

          def head
            div(class: "svc-head") do
              h2(class: "card-title") { definition.name }
              Button(small: true, variant: :gh, icon: CLOSE_ICON, **close)
            end
          end

          def held(yes, color, held_key, lacking_key)
            yes ? Pill(color:) { t(held_key) } : Pill(color: :orange) { t(lacking_key) }
          end

          def jobs
            return if @row.jobs.empty?

            label(t(".jobs"))
            @row.jobs.each { line(it[:name], it[:every]) }
            SyncFailures(failures: @row.failing_jobs.map { it[:failure] })
          end

          def label(text) = p(class: "svc-group-label") { text }

          def line(name, note = nil, &)
            div(class: "svc-line") do
              span do
                span(class: "svc-line-name") { name }
                span(class: "svc-line-note") { note } if note
              end
              yield if block_given?
            end
          end

          def no_credentials
            return unless definition.auth == "none"

            Hint do
              plain(t(".no_credentials"))
              whitespace
              a(class: "settings-link", href: "#{path(:admin_webmentions)}#webmention-settings") { t(".bridgy") }
            end
          end

          def powers
            label(t(".powers"))
            ul(class: "svc-powers") { definition.powers.each { |power| li { power } } }
          end

          def scope(scope)
            granted = @row.connection.scopes.include?(scope[:id])
            line(scope[:label], scope[:why]) { held(granted, :green, ".granted", ".not_granted") }
          end

          def way = line(t(".way")) { Pill { t(by_token? ? ".token" : ".oauth") } }
        end
      end
    end
  end
end
