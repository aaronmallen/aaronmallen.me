# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Social
        class Index < View
          include Components::Social

          ACCOUNTS_SEPARATOR = " and "

          prop :accounts, Blog::Types::Array.of(Blog::Types::String)
          prop :filter, Blog::Types::SocialQueue
          prop :items, Blog::Types::Instance(Blog::Paged)
          prop :now, Blog::Types::Time
          prop :queued, Blog::Types::Integer
          prop :records, Blog::Types::Hash.optional
          prop :suggestion_counts, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::Integer)
          prop :suggestions, Blog::Types::Hash
          prop :writing, Blog::Types::Bool, default: false
          prop :composer, Blog::Types::Hash, :**

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
              records: @records, kind: "social_post", id:, fields: { filter: @filter, edit: id },
              find_path: path(:admin_social),
            )
          end

          def queue
            Queue(filter: @filter, page: @items, now: @now, suggestion_counts: @suggestion_counts)
          end

          def sub = dotted(cross_posting, t(".queued", count: @queued))

          def suggestions
            Suggestions(filter: @filter, **@suggestions) if @suggestions[:edits].any?
          end
        end
      end
    end
  end
end
