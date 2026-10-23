# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tags
        class Show < View
          LIVE_TABLES = %w[
            decision_options decision_tags decisions journal_entries journal_entry_tags mail_thread_tags mail_threads
            note_tags notes post_tags posts project_tags projects sprints task_comments task_contributors task_links
            task_series task_tags work_sessions
          ].freeze
          MAIL_THREAD = Blog::Types::RecordKind["mail_thread"]
          NOTE = Blog::Types::RecordKind["note"]
          PRIVATE = Blog::Types::TagScope["private"]
          PROJECT = Blog::Types::TagScope["project"]
          PUBLIC = Blog::Types::TagScope["public"]
          PUBLISHED = Blog::Types::PostStatus["published"]

          KINDS = {
            posts: [PUBLIC, :post, ".kinds.posts"],
            projects: [PUBLIC, :project, ".kinds.projects"],
            tasks: [PRIVATE, :task, ".kinds.tasks"],
            journal_entries: [PRIVATE, :journal_entry, ".kinds.journal_entries"],
            decisions: [PRIVATE, :decision, ".kinds.decisions"],
            notes: [PRIVATE, :note, ".kinds.notes"],
            messages: [PRIVATE, :message, ".kinds.messages"],
          }.freeze
          SCOPES = { PUBLIC => ".scopes.public", PRIVATE => ".scopes.private" }.freeze

          prop :overview, Blog::Types::Instance(::Tags::Structs::Overview)
          prop :kind, Blog::Types::TagKind.optional
          prop :project, Blog::Types::Instance(ROM::Struct).optional, default: nil

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            back
            PageHead(title: heading, kicker: t(".kicker"), sub: t(".count", count: @overview.count))

            return Empty { t(".empty") } if @overview.empty?

            groups
          end

          private

          def all_link(kind)
            div(class: "review-foot") do
              a(class: "today-link", href: path(route, **params(kind))) do
                t(".all", count: @overview.counts.fetch(kind))
              end
            end
          end

          def back
            return BackLink(href: path(route, **params)) { heading } if @kind
            return BackLink(href: path(:admin_project, id: @project.id)) { @project.name } if @project

            BackLink(href: tags_path) { t(".back") }
          end

          def decision(decision)
            ListItem(title: decision.title, href: path(:admin_decision, id: decision.id)) do
              StatusPill(status: decision.status)
            end
          end

          def group(kind, scope, row, title)
            records = @overview.pages.fetch(kind)
            return if records.rows.empty?

            Card(label: label(scope), title: t(title), data: { key_list: true }) do |card|
              card.side { side_tag(scope) }
              records.rows.each { send(row, it) }
              all_link(kind) if records.more && !@kind
            end
          end

          def groups
            KINDS.slice(*@overview.pages.keys).each { |kind, (scope, row, title)| group(kind, scope, row, title) }
            Pager(page: @overview.pages.values.first, route:, params: params(@kind)) if @kind
          end

          def heading = Components::Tag::PREFIX + name

          def journal_entry(entry)
            day = entry.entry_date
            href = Blog::Helpers::RecordKinds.journal_day(routes, day)

            ListItem(title: journal_title(entry), href:) do |item|
              item.sub { l(day, format: :medium) }
            end
          end

          def journal_title(entry)
            line = entry.body.each_line.map(&:strip).find { !it.empty? }

            Helpers::Short.title(line.to_s)
          end

          def label(scope) = @project ? @project.name : t(SCOPES.fetch(scope))

          def message(thread)
            ListItem(title: thread.subject, href: record_path(MAIL_THREAD, thread.id)) do |item|
              item.sub { Moment(at: thread.received_at) }
            end
          end

          def name = @overview.name

          def note(note)
            ListItem(title: note.title, href: record_path(NOTE, note.id)) do |item|
              item.sub { Moment(at: note.updated_at) }
            end
          end

          def params(kind = nil) = { key: @project&.key, name:, kind: }.compact

          def post(post)
            ListItem(title: post.title, href: path(:admin_edit_post, id: post.id)) do |item|
              item.sub { Moment(at: post.published_at) } if post.status == PUBLISHED
              StatusPill(status: post.status)
            end
          end

          def project(project)
            ListItem(title: project.name, href: path(:admin_edit_project, id: project.id)) do
              StatusPill(status: project.archived? ? :archived : :active)
            end
          end

          def record_path(kind, id) = Blog::Helpers::RecordKinds.path(routes, kind, id:, day: nil)

          def route = @project ? :admin_project_tag : :admin_tag

          def side_tag(scope) = Tag(tag: @overview.tag(@project ? PROJECT : scope), project_key: @project&.key)

          def tags_path = "#{path(:admin_settings_tagging)}##{Helpers::TagList::TAGS}"

          def task(task)
            ListItem(title: task.title, href: path(:admin_task, id: task.id)) do |item|
              item.sub { Components::Tasks::Closed(task:) } if task.closed?
            end
          end
        end
      end
    end
  end
end
