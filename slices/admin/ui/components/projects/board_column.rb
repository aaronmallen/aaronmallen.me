# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class BoardColumn < Component
          prop :project_id, Blog::Types::Integer
          prop :name, Blog::Types::TaskColumn
          prop :tasks, Blog::Types::Array
          prop :count, Blog::Types::Integer
          prop :board, Blog::Types::Instance(Blog::BoardSizes)
          prop :return_to, Blog::Types::String
          prop :query, Blog::Types::Hash

          def view_template
            label = t(BoardCard::NAMES.fetch(@name))

            section(class: ["kcol", "k-#{@name}"], aria: { label: }, data: { board_column: @name }) do
              head(label)
              div(class: "kcol-list", data: { key_list: true }) do
                next p(class: "kcol-empty") { t(BoardList::EMPTY) } if @tasks.empty?

                @tasks.each { BoardCard(task: it, project_id: @project_id, return_to: @return_to) }
              end
              LoadMore(
                project_id: @project_id, board: @board, column: @name, count: @count, shown: @tasks.size, query: @query,
              )
            end
          end

          private

          def head(label)
            div(class: "kcol-head") do
              span(class: "kcol-dot", aria: { hidden: true })
              h2 { label }
              span(class: "kcol-count") { @count.to_s }
            end
          end
        end
      end
    end
  end
end
