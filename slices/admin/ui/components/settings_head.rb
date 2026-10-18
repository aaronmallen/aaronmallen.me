# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SettingsHead < Component
        TABS = {
          socials: :admin_settings_socials, tagging: :admin_settings_tagging, services: :admin_settings_services,
          security: :admin_security, jobs: :admin_settings_jobs,
        }.freeze
        UNKNOWN = "!"
        LABELS = TABS.keys.to_h { [it, ".tabs.#{it}"] }.freeze

        prop :tab, Blog::Types::Symbol.enum(*TABS.keys).optional, default: nil
        prop :title, Blog::Types::String

        include Deps[
          cron_queries: "activity.repos.cron_queries", job_queries: "activity.repos.job_queries",
          list_services: "operations.list_services", person_queries: "social.repos.person_queries",
          task_rule_queries: "tasks.repos.task_rule_queries",
        ]

        def view_template
          content_for(:title, @title)
          PageHead(title: t(".heading"), sub: t(".lede")) do
            yield if block_given?
            maintenance if @tab
          end
          tabs if @tab
        end

        private

        def counts
          {
            socials: person_queries.count, tagging: task_rule_queries.count, services: list_services.count, jobs:,
          }
        end

        def jobs
          flagged = job_queries.flagged
          flagged ? flagged + cron_queries.failed : UNKNOWN
        end

        def maintenance
          ButtonForm(
            action: path(:admin_activate_maintenance), label: t(".maintenance.activate"), variant: :warn,
            icon: "fa-solid fa-person-digging", confirm: t(".maintenance.confirm"),
          )
        end

        def tab(name, route, count)
          a(class: "screen-tab", href: path(route), aria: { current: ("page" if name == @tab) }) do
            plain t(LABELS.fetch(name))
            tab_count(count) if count
          end
        end

        def tab_count(count)
          whitespace
          span(class: "settings-tab-count") { count.to_s }
        end

        def tabs
          found = counts

          div(class: "screen-tabs") do
            nav(class: "screen-tabs-list", aria: { label: t(".tabs.label") }) do
              TABS.each { |name, route| tab(name, route, found[name]) }
            end
          end
        end
      end
    end
  end
end
