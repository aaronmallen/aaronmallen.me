# frozen_string_literal: true

require "rack/utils"

module Admin
  module UI
    module Components
      class CommitsCard < Component
        COMMIT = Blog::Types::ActivityKind["commit"]
        SHA_LENGTH = 7

        prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :last_synced_at, Blog::Types::Time.optional
        prop :repos, Blog::Types::Integer
        prop :today, Blog::Types::Date
        prop :configured, Blog::Types::Bool

        def view_template
          Card(label: t(".label"), title: t(".title")) do |card|
            card.side { import_form }
            sub_line
            Hint { t(".no_token") } unless @configured
            entry_list
          end
        end

        private

        def activity_link
          div(class: "commits-foot") do
            Button(href: activity_path, variant: :gh, small: true, icon: "fa-solid fa-timeline") { t(".activity") }
          end
        end

        def activity_path
          query = { from: @today.iso8601, to: @today.iso8601, types: { COMMIT => Blog::Constants::CHECKED } }

          "#{path(:admin_activity)}?#{Rack::Utils.build_nested_query(query)}"
        end

        def button_label(state, icon, text, hidden: false)
          span(class: "btn-label", data: { "commits_#{state}": "" }, hidden:) do
            IconLabel(icon:) { text }
          end
        end

        def entry_counts(commit)
          p(class: "commit-counts") do
            span(class: "commit-added") { "+#{commit.additions}" }
            span(class: "commit-removed") { "−#{commit.deletions}" }
          end
        end

        def entry_list
          return Empty { t(".empty") } if @entries.empty?

          div(class: "commits") { @entries.each { entry_row(it) } }
          activity_link
        end

        def entry_main(commit)
          div(class: "commit-main") do
            p(class: "commit-message") { CommitMessage.subject(commit.message) }
            p(class: "commit-meta") { "#{commit.repo}#{DOT}#{l(commit.commit_time, format: :clock)}" }
          end
        end

        def entry_row(commit)
          article(class: "commit") do
            span(class: "commit-sha") { commit.sha[0, SHA_LENGTH] }
            entry_main(commit)
            entry_counts(commit)
          end
        end

        def import_button
          Button(variant: :pri, type: "submit", small: true, disabled: !@configured) do
            button_label(:idle, "fa-solid fa-rotate", t(".import"))
            button_label(:busy, "fa-solid fa-rotate commit-spinner", t(".importing"), hidden: true)
          end
        end

        def import_form
          Form(action: path(:admin_import_commits), data: { commits_import: "" }) do
            import_button
          end
        end

        def sub_line
          p(class: "commits-sub") do
            Icon("fa-brands fa-github commits-sub-icon")
            plain "#{synced}#{DOT}#{t('.repos', count: @repos)}"
          end
        end

        def synced
          return t(".never_synced") unless @last_synced_at
          return t(".synced_on", at: l(Blog::TimeZone.local(@last_synced_at), format: :medium)) unless synced_today?

          t(".synced_today", time: l(Blog::TimeZone.local(@last_synced_at), format: :clock))
        end

        def synced_today? = Blog::TimeZone.today(@last_synced_at) == @today
      end
    end
  end
end
