# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Social
        class Index < View
          include Components::Social

          ACCOUNTS_SEPARATOR = " and "
          SEPARATOR = " · "

          def initialize(
            accounts:, filter:, items:, now:, queued:, records:, suggestion_counts:, suggestions:, writing: false,
            **composer
          )
            super()
            @accounts = accounts
            @composer = composer
            @filter = filter
            @queue = { page: items, now:, suggestion_counts: }
            @queued = queued
            @records = records
            @suggestions = suggestions
            @writing = writing
          end

          def view_template
            PageHead(title: t(".heading"), sub:)

            Grid(columns: 2) do
              SideStack do
                suggestions
                composer
                linked if @records
              end
              SideStack { queue }
            end
            render Components::People::PersonDialog.new
          end

          private

          def composer = Composer(**@composer, autofocus: @writing)

          def cross_posting
            return t(".no_accounts") if @accounts.empty?

            t(".cross_posting", accounts: @accounts.join(ACCOUNTS_SEPARATOR))
          end

          def linked
            id = @composer[:editing]

            RecordLinks::Section(
              records: @records, scope: "social-post-#{id}-record", id:, fields: { filter: @filter, edit: id },
              unlink_route: :admin_unlink_social_post_record, link_path: path(:admin_link_social_post_record, id:),
              find_path: path(:admin_social),
            )
          end

          def queue
            Queue(filter: @filter, **@queue)
          end

          def sub = [cross_posting, t(".queued", count: @queued)].join(SEPARATOR)

          def suggestions
            Suggestions(filter: @filter, **@suggestions) if @suggestions[:edits].any?
          end
        end
      end
    end
  end
end
