# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Mail
        class Index < View
          include Components::Mail

          ACCOUNT_ID = "mail-account"
          FORM = Blog::Types::MailProvider["contact_form"]
          SEARCH_ID = "mail-search"
          SHOWS = Blog::Types::MailShow.values.to_h { [it, "ui.views.mail.index.shows.#{it}"] }.freeze
          TONES = %w[gr or bl vi].freeze

          prop :accounts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :counts, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer)
          prop :draft, Blog::Types::Hash.optional
          prop :labels, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::Array)
          prop :list, Blog::Types::Hash
          prop :open, Blog::Types::Instance(ROM::Struct).optional
          prop :person, Blog::Types::Instance(ROM::Struct).optional
          prop :reasons, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::String)
          prop :senders, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :tasks, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::Integer)
          prop :threads, Blog::Types::Instance(Blog::Structs::Paged)
          prop :unread, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::Integer)

          def view_template
            content_for(:live_tables, %w[record_links service_connections])
            PageHead(title: t(".heading"), sub:) do
              filter_form
              tools
            end
            div(class: "mail-layout") do
              Folders(list: @list, counts: @counts, labels: shown_labels, chips:)
              panes
            end
            Pager(page: @threads, route: :admin_mail, params: @list)
          end

          private

          def account_field
            label(class: "sr-only", for: ACCOUNT_ID) { t(".account") }
            Select(id: ACCOUNT_ID, name: "account", options: account_options, selected: @list[:account]&.to_s)
          end

          def account_options
            all = { "" => counted(t(".all_accounts"), @unread.values.sum) }
            all.merge(@accounts.to_h { [it.id.to_s, counted(it.name, @unread.fetch(it.id, 0))] })
          end

          def chips
            @chips ||= @accounts.each_with_index.to_h do |account, index|
              [account.id, [account.name, account.provider == FORM ? "pk" : TONES[index % TONES.size]]]
            end
          end

          def counted(text, count) = count.zero? ? text : "#{text} · #{count}"

          def empty
            return Empty { t(".no_match") } if @list[:search]

            name = folder_name
            Empty { t(@list[:show] == Helpers::MailList::UNREAD ? ".nothing_unread" : ".empty", name:) }
          end

          def filter_form
            AutoForm(action: path(:admin_mail), role: "search", class: "mail-filters") do
              account_field
              FolderSelect(list: @list, counts: @counts, labels: shown_labels, chips:)
              SegmentedControl(label: t(".show"), name: "show", options: shows, selected: @list[:show])
              search_field
            end
          end

          def folder_name
            label = Helpers::MailList.label(@list[:folder])
            label ? "##{label}" : t(Folders::NAMES.fetch(@list[:folder]))
          end

          def panes
            div(class: "mail-panes") do
              Card(class: "mail-list") do
                Bulk(list: @list, page: @threads.number, labels: shown_labels, chips:, count: @threads.rows.size)
                @threads.rows.empty? ? empty : rows
              end
              Card(class: "mail-pane") { reader }
            end
          end

          def reader
            return Empty { t(".pick") } unless @open

            account = @accounts.find { it.id == @open.mail_account_id }
            form = account.provider == FORM
            Reader(
              thread: @open, person: @person, list: @list, chip: chips.fetch(account.id), form:, own: account.address,
              task: @tasks[@open.id], reason: @reasons[@open.id],
            ) { Reply(thread: @open, senders: @senders, list: @list, form:, account: account.name, draft: @draft) }
          end

          def rows
            div(data: { key_list: true }) do
              @threads.rows.each do |thread|
                chip = chips.fetch(thread.mail_account_id) unless @list[:account]
                Row(
                  thread:, list: @list, page: @threads.number, chip:, open: thread.id == @open&.id,
                  task: @tasks[thread.id], waiting: @reasons.key?(thread.id),
                )
              end
            end
          end

          def search_field
            SearchField(
              id: SEARCH_ID, label: t(".search"), name: "search", value: @list[:search], placeholder: t(".placeholder"),
            )
          end

          def shown_labels = @list[:account] ? @labels.slice(@list[:account]) : @labels

          def shows = SHOWS.transform_values { t(it) }

          def sub
            gmail = @accounts.count { it.provider != FORM }
            form = @accounts.any? { it.provider == FORM }

            t(".sub", count: @unread.values.sum, sources: t(form ? ".with_form" : ".gmail", count: gmail))
          end

          def tools
            BulkToggle(form: Bulk::ID)
            Button(href: path(:admin_mail_settings), variant: :gh, icon: "fa-solid fa-gear") { t(".settings") }
            Compose(senders: @senders, list: @list, draft: @draft)
          end
        end
      end
    end
  end
end
