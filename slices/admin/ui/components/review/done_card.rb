# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class DoneCard < Component
          prop :done, Blog::Types::Hash.map(Blog::Types::Date, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct)))
          prop :credits, Blog::Types::Hash
          prop :choices, Blog::Types::Hash
          prop :keep, Blog::Types::Hash

          def view_template
            Card(title: t(".title"), id: "review-done") do
              filter_form
              next Empty { t(".empty") } if @done.empty?

              @done.each { |day, tasks| day_group(day, tasks) }
            end
          end

          private

          def credit_words(contributors) = Credits.words(contributors) { |key, **words| t(key, **words) }

          def day_group(day, tasks)
            section(class: "review-group") do
              h3(class: "review-group-title") { l(day, format: :weekday) }
              tasks.each { ListItem(**item(it)) }
            end
          end

          def filter_form
            AutoForm(action: path(:admin_review)) do
              div(class: "form-stack") do
                @keep.each { |name, value| input(type: "hidden", name: name.to_s, value:) }
                ContributorFilter(credits: @credits, choices: @choices)
              end
            end
          end

          def item(task)
            {
              title: task.title,
              href: path(:admin_task, id: task.task_id),
              sub: dotted(Blog::Helpers::Figures.hours(task.worked_seconds), credit_words(task.contributors)),
            }
          end
        end
      end
    end
  end
end
