# frozen_string_literal: true

module Public
  module UI
    module Views
      module Tasks
        class Show < View
          prop :project, Blog::Types::Instance(ROM::Struct)
          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :comments, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :related, Blog::Types::Array.of(Blog::Types::Array)

          include Deps["settings"]

          def view_template
            page_meta
            back_link
            article do
              head
              notes if written?(@task.note)
              related unless @related.empty?
              comments unless @comments.empty?
            end
          end

          private

          def back_link
            a(class: "post-back", href: path(:project, slug: @project.slug)) do
              IconLabel(icon: "fa-solid fa-arrow-left") { t(".back", name: @project.name) }
            end
          end

          def closed
            dt { t([".closed", @task.status].join(".")) }
            dd { Moment(at: @task.completed_at, format: :day) }
          end

          def comment(comment)
            li(class: "task-comment") do
              p(class: "task-comment-head") do
                span { comment.synced? ? comment.author || t(".unknown_author") : settings.owner_name }
                whitespace
                Moment(at: comment.created_at, format: :day)
              end
              note_body(comment.body)
            end
          end

          def comments
            section(class: "task-section") do
              h2(class: "kicker") { t(".comments") }
              ol(class: "task-comments") { @comments.each { comment(it) } }
            end
          end

          def fact(key, value)
            dt { t([".facts", key].join(".")) }
            dd { value }
          end

          def facts
            dl(class: "task-facts") do
              fact(:status, t([".statuses", @task.status].join(".")))
              fact(:column, t([".columns", @task.board_column].join(".")))
              closed if @task.completed_at
              source if @task.source
            end
          end

          def head
            header(class: "hd") do
              span(class: "kicker") { t(".kicker", label: @task.label) }
              h1 { @task.title }
              facts
            end
          end

          def note_body(markdown)
            div(class: "post-body markdown-body") { raw(safe(::Markdown::Note.to_html(markdown).strip)) }
          end

          def notes
            section(class: "task-section") do
              h2(class: "kicker") { t(".notes") }
              note_body(@task.note)
            end
          end

          def page_meta
            content_for(:title, t(".title", label: @task.label, title: @task.title))
            content_for(:description, t(".description", label: @task.label, name: @project.name))
          end

          def related
            section(class: "task-section") do
              h2(class: "kicker") { t(".related") }
              ul(class: "task-related") { @related.each { |link, slug| related_task(link, slug) } }
            end
          end

          def related_task(link, slug)
            li do
              span(class: "meta") { t([".links", link.label].join(".")) }
              whitespace
              a(href: path(:project_task, slug:, number: link.task.id)) do
                plain link.task.label
                whitespace
                plain link.task.title
              end
            end
          end

          def source
            dt { t(".facts.source") }
            dd do
              a(href: @task.source.url, rel: "noopener") do
                plain ::Tasks::Structs::SourceReference.for(@task.source).name || @task.source.url
              end
            end
          end
        end
      end
    end
  end
end
