# frozen_string_literal: true

require "rack/utils"

module Admin
  module UI
    module Components
      class CommitsCard < Component
        COMMIT = Blog::Types::ActivityKind["commit"]
        OWNER_SEPARATOR = "/"
        SHA_LENGTH = 7

        prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :last_synced_at, Blog::Types::Time.optional
        prop :repos, Blog::Types::Integer
        prop :today, Blog::Types::Date
        prop :configured, Blog::Types::Bool
        prop :totals, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::Integer)

        def view_template
          Card(title: t(".title")) do |card|
            card.side { import_form }
            Hint { t(".no_token") } unless @configured
            stat
            entry_list
          end
        end

        private

        def activity_link
          div(class: "commits-foot") do
            a(class: "today-link", href: activity_path) { t(".activity") }
          end
        end

        def activity_path
          query = { from: @today.iso8601, to: @today.iso8601, types: { COMMIT => Blog::Constants::CHECKED } }

          "#{path(:admin_activity)}?#{Rack::Utils.build_nested_query(query)}"
        end

        def button_label(state, icon, text, hidden: false)
          span(class: "bt-label", data: { "commits_#{state}": "" }, hidden:) do
            Icon(icon)
            span(class: "sr-only") { text }
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

          p(class: "today-para") { t(".latest", count: @repos, subject: subject(@entries.first)) }
          details(class: "today-more") do
            entry_summary
            div(class: "commits") { @entries.each { entry_row(it) } }
            activity_link
          end
        end

        def entry_meta(commit)
          [commit.sha[0, SHA_LENGTH], repo(commit), l(commit.commit_time, format: :clock)].join(DOT)
        end

        def entry_row(commit)
          a(class: "commit", href: path(:admin_commit, id: commit.id)) do
            div(class: "commit-main") do
              p(class: "commit-message") { subject(commit) }
              p(class: "commit-meta") { entry_meta(commit) }
            end
            entry_counts(commit)
          end
        end

        def entry_summary
          summary do
            Icon("fa-solid fa-chevron-right today-more-chev")
            plain t(".commits")
            span(class: "commits-synced") { synced }
          end
        end

        def import_button
          Button(type: "submit", title: t(".import"), disabled: !@configured) do
            button_label(:idle, "fa-solid fa-rotate", t(".import"))
            button_label(:busy, "fa-solid fa-rotate commit-spinner", t(".importing"), hidden: true)
          end
        end

        def import_form
          Form(action: path(:admin_import_commits), class: "commits-import", data: { commits_import: "" }) do
            import_button
          end
        end

        def repo(commit) = commit.repo.split(OWNER_SEPARATOR).last

        def stat
          return if @totals[:commits].zero?

          p(class: "today-stat") do
            plain t(".count", count: @totals[:commits])
            small do
              span(class: "commit-added") { "+#{@totals[:additions]}" }
              whitespace
              span(class: "commit-removed") { "−#{@totals[:deletions]}" }
            end
          end
        end

        def subject(commit) = Helpers::CommitMessage.subject(commit.message)

        def synced
          return plain(t(".never_synced")) unless @last_synced_at
          return Stamped(text: t(".synced_on", at: Stamped::MARK), at: @last_synced_at) unless synced_today?

          Stamped(text: t(".synced_today", time: Stamped::MARK), at: @last_synced_at, format: :clock)
        end

        def synced_today? = Blog::TimeZone.today(@last_synced_at) == @today
      end
    end
  end
end
