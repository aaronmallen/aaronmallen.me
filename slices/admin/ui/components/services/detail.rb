# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Detail < Component
          CHANGE_ICON = "fa-solid fa-sliders"
          GOOGLE = "google"

          prop :row, Blog::Types::Instance(Structs::ServiceRow)
          prop :connectable, Blog::Types::Bool

          def view_template
            Head(title: definition.name, definition:)
            status
            powers
            access if definition.oauth? && @row.connection
            work if definition.id == GOOGLE && @row.connection
            credentials
            jobs
            Actions(row: @row, connectable: @connectable)
          end

          private

          def access
            label(t(".access"))
            way if definition.credentials?
            scopes
            Hint { Stamped(text: t(".connected", time: Stamped::MARK), at: @row.connection.created_at) }
          end

          def by_token? = @row.connection.by_credentials?

          def change
            return if by_token? || !definition.optional?

            connection = @row.connection
            opener = Dialog.opens(ConnectDialog.id_for(definition, connection))
            Button(small: true, variant: :gh, icon: CHANGE_ICON, **opener) { t(".change") }
            ConnectDialog(definition:, connection:)
          end

          def credentials
            return no_credentials if @row.env.empty?

            label(t(definition.oauth? ? ".app_credentials" : ".credentials"))
            @row.env.each { |name, set| line(name, name: "svc-env") { held(set, nil, ".set", ".missing") } }
            Hint { t(".environment") }
          end

          def definition = @row.definition

          def held(yes, color, held_key, lacking_key)
            yes ? Pill(color:) { t(held_key) } : Pill(color: :orange) { t(lacking_key) }
          end

          def job_name(job) = t("ui.components.sync_failures.syncs").fetch(job[:sync].to_sym)

          def jobs
            return if @row.jobs.empty?

            label(t(".jobs"))
            @row.jobs.each { line(job_name(it), it[:every], name: "svc-job") }
            SyncFailures(failures: @row.failing_jobs.map { it[:failure] })
          end

          def label(text) = p(class: "svc-group-label") { text }

          def lapse_date = l(Blog::TimeZone.today(@row.connection.lapses_at), format: :medium)

          def line(text, note = nil, name: "svc-line-name", &)
            div(class: "svc-line") do
              span do
                span(class: name) { text }
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
              a(class: "settings-link", href: path(:admin_webmention_settings)) { t(".bridgy") }
            end
          end

          def powers
            label(t(".powers"))
            ul(class: "svc-powers") { definition.powers.each { |power| li { power } } }
          end

          def scope(scope)
            line(scope[:label], scope[:why]) do
              next Pill(color: :green) { t(".granted") } if definition.granted?(scope, @row.connection.scopes)

              scope[:optional] ? Pill { t(".left_off") } : Pill(color: :orange) { t(".not_granted") }
            end
          end

          def scopes
            return if by_token? && @row.connection.scopes.empty?

            definition.scopes.each { scope(it) }
            change
          end

          def status
            p(class: "svc-status") do
              StatusPill(status: @row.status)
              span(class: "svc-account") { @row.account } if @row.account
            end
            Hint { t(".revoked", name: definition.name) } if @row.status == :reconnect
            Hint { t(".lapsed", name: definition.name) } if @row.status == :lapsed
            Hint { t(".lapsing", name: definition.name, date: lapse_date) } if @row.status == :lapsing
          end

          def way = line(t(".way")) { Pill { t(by_token? ? ".token" : ".oauth") } }

          def work
            Form(action: path(:admin_work_service, id: @row.connection.id), data: { autosubmit: "", morph: true }) do
              Checkbox(switch: true, label: t(".work"), name: "work", checked: @row.connection.work)
              noscript { Button(type: "submit", small: true) { t(".save") } }
            end
            Hint { t(".work_hint") }
          end
        end
      end
    end
  end
end
