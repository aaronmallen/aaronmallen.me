# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Row < Component
          READ_KEY = "r"
          UNREAD = Blog::Types::MessageStatus["unread"]

          prop :thread, Blog::Types::Instance(ROM::Struct)
          prop :list, Blog::Types::Hash
          prop :page, Blog::Types::Integer
          prop :chip, Blog::Types::Array.optional
          prop :open, Blog::Types::Bool
          prop :task, Blog::Types::Integer.optional, default: nil
          prop :waiting, Blog::Types::Bool, default: false

          def view_template
            div(id: "thread-#{@thread.id}", class: ["mail-row", ("unread" if unread?), ("snoozed" if snoozed?),
                                                    ("on" if @open)],
                data: { key_row: true, menu: menu_path, mail_drag: @thread.subject }) do
              BulkCheck(form: Bulk::ID, value: @thread.id, label: t(".pick", subject: @thread.subject))
              Form(action: path(:admin_open_mail, id: @thread.id), class: "mail-row-form") do
                HiddenFields(values: { **@list, **Blog::Structs::Page.query(@page) })
                button(type: "submit", class: "mail-row-open", **keyed) { summary }
              end
            end
          end

          private

          def draft
            span(class: "mail-draft") { t(".draft") }
            span(class: "mail-dim") { t(".to", address: @thread.reply_to) }
          end

          def head
            span(class: "mail-row-head") do
              span(class: "mail-row-from") do
                span(class: "sr-only") { t(".unread_mark") } if unread?
                @thread.draft ? draft : plain(@thread.sender.to_s)
              end
              span(class: "mail-row-when") do
                Icon("fa-solid fa-star", label: t(".starred")) if @thread.starred
                Moment(at: @thread.received_at, format: :short)
              end
            end
          end

          def keyed
            return { data: { key_open: true } } unless unread?

            { aria: { keyshortcuts: READ_KEY }, data: { key_open: true, key: READ_KEY, key_label: t(".read_key") } }
          end

          def labels
            [*@thread.mail_labels, *@thread.tags].map(&:name).uniq - [Helpers::MailList.label(@list[:folder])]
          end

          def marks
            Mark(icon: "fa-regular fa-clock", text: t(".wakes", date: wake_day)) if snoozed?
            span { t(".archived") } if @thread.archived
            Mark(icon: "fa-solid fa-check", text: t(".task", id: @task), tone: "mail-task") if @task
            Mark(icon: "fa-solid fa-inbox", text: t(".waiting"), tone: "mail-why") if @waiting && !snoozed?
          end

          def menu_path = path(:admin_mail_menu, id: @thread.id, **@list, **Blog::Structs::Page.query(@page))

          def meta
            span(class: "mail-row-meta") do
              Account(chip: @chip) if @chip
              labels.each { |name| span(class: "mail-label") { "##{name}" } }
              marks
            end
          end

          def snoozed? = @thread.snoozed_until&.>(Time.now)

          def summary
            head
            span(class: "mail-row-subject") do
              plain @thread.subject
              span(class: "mail-dim") { " · #{@thread.message_count}" } if @thread.message_count > 1
            end
            meta
            span(class: "mail-row-preview") { @thread.preview }
          end

          def unread? = @thread.status == UNREAD

          def wake_day = l(Blog::TimeZone.local_date(@thread.snoozed_until), format: :medium)
        end
      end
    end
  end
end
