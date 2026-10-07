# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tags
        class Show < View
          PRIVATE = Blog::Types::TagScope["private"]
          PUBLIC = Blog::Types::TagScope["public"]
          PUBLISHED = Blog::Types::PostStatus["published"]
          TEXT_LIMIT = 80

          KINDS = {
            posts: [PUBLIC, :post, ".kinds.posts"],
            projects: [PUBLIC, :project, ".kinds.projects"],
            tasks: [PRIVATE, :task, ".kinds.tasks"],
            journal_entries: [PRIVATE, :journal_entry, ".kinds.journal_entries"],
            decisions: [PRIVATE, :decision, ".kinds.decisions"],
          }.freeze
          SCOPES = { PUBLIC => ".scopes.public", PRIVATE => ".scopes.private" }.freeze

          prop :summary, Blog::Types::Instance(::Tags::Structs::Summary)

          def view_template
            BackLink(href: path(:admin_tags)) { t(".back") }
            PageHead(title: Components::Tag::PREFIX + @summary.name, kicker: t(".kicker"), sub: t(".count", count:))

            return Empty { t(".empty") } if @summary.empty?

            KINDS.each { |kind, (scope, row, title)| group(kind, scope, row, title) }
          end

          private

          def count = KINDS.keys.sum { @summary.public_send(it).size }

          def decision(decision)
            ListItem(title: decision.title, href: path(:admin_decision, id: decision.id)) do
              Components::Decisions::Status(status: decision.status)
            end
          end

          def group(kind, scope, row, title)
            records = @summary.public_send(kind)
            return if records.empty?

            Card(label: t(SCOPES.fetch(scope)), title: t(title), data: { key_list: true }) do |card|
              card.side { Tag(tag: @summary.tag(scope)) }
              records.each { send(row, it) }
            end
          end

          def journal_entry(entry)
            day = entry.entry_date
            href = "#{path(:admin_journal, to: day.iso8601)}##{Components::Journal::Day.anchor(day)}"

            ListItem(title: journal_title(entry), href:) do |item|
              item.meta { p(class: "li-sub") { l(day, format: :medium) } }
            end
          end

          def journal_title(entry)
            line = entry.body.each_line.map(&:strip).find { !it.empty? }

            Blog::Truncation.cut(line.to_s, keep: TEXT_LIMIT)
          end

          def post(post)
            ListItem(title: post.title, href: path(:admin_edit_post, id: post.id)) do |item|
              item.meta { p(class: "li-sub") { Moment(at: post.published_at) } } if post.status == PUBLISHED
              StatusPill(status: post.status)
            end
          end

          def project(project)
            ListItem(title: project.name, href: path(:admin_edit_project, id: project.id)) do
              Components::Projects::StatusPill(archived: project.archived?)
            end
          end

          def task(task)
            ListItem(title: task.title, href: path(:admin_task, id: task.id)) do |item|
              item.meta { p(class: "li-sub") { Components::Tasks::Closed(task:) } } if task.closed?
            end
          end
        end
      end
    end
  end
end
