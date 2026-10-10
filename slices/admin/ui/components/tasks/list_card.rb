# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class ListCard < Component
          BLURBS = Blog::Types::TaskList.values.to_h { [it, ".blurbs.#{it}"] }.freeze
          CARRIED = :carried_in
          EMPTY = Blog::Types::TaskList.values.to_h { [it, ".empty.#{it}"] }.freeze
          EXTERNAL = Blog::Types::TaskTab["external"]
          TODAY = Blog::Types::TaskTab["today"]

          prop :counts, Blog::Types::Hash.map(Blog::Types::String | Blog::Types::Symbol, Blog::Types::Integer)
          prop :lead, Blog::Types::Integer.optional
          prop :query, Blog::Types::String
          prop :tab, Blog::Types::TaskTab
          prop :tasks, Blog::Types::Instance(Blog::Structs::Paged)
          prop :today, Blog::Types::Date

          def view_template
            Card(title:, class: "task-list", data: { key_list: true }) do |card|
              card.side do
                ImportActs() if external?
                span(class: "card-note") { note }
              end
              p(class: "card-blurb") { t(BLURBS.fetch(@tab)) } if BLURBS.key?(@tab)
              rows
              QuickAdd(filter: @tab, placeholder: t(".add_to", list: @tab)) unless external?
            end
          end

          private

          def carried = @counts.fetch(CARRIED)

          def empty_key = today? ? ".empty.today" : EMPTY.fetch(@tab)

          def external? = @tab == EXTERNAL

          def filtering? = !@query.empty?

          def note
            counts = [t(".open", count: filtering? ? @tasks.rows.size : @counts.fetch(@tab))]
            counts << t(".carried_in", count: carried) if today? && carried.positive?

            dotted(*counts)
          end

          def row(task)
            Row(task:, filter: @tab, today: @today, lead: @lead, ordered: !filtering?, scheduled:, bulk: Bulk::ID,
                large: today?)
          end

          def rows
            return Empty { t(filtering? ? ".empty.no_match" : empty_key) } if @tasks.rows.empty?

            Bulk(filter: @tab, page: @tasks.number, query: @query)
            @tasks.rows.each { row(it) }
            Pager(page: @tasks, route: :admin_tasks, params: { filter: @tab, q: (@query unless @query.empty?) }.compact)
          end

          def scheduled = (@today if today?)

          def title = today? ? t(".sprint", date: l(@today, format: :short)) : t(Helpers::TaskLists.title(@tab))

          def today? = @tab == TODAY
        end
      end
    end
  end
end
