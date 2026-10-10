# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class DoneCard < Component
          COMPLETED = Blog::Types::TaskTab["completed"]
          GROUPS = { "tag" => ".by_tag", "project" => ".by_project" }.freeze
          TAG = Blog::Types::ReviewGroup["tag"]

          prop :done, Blog::Types::Hash.map(Blog::Types::Date, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct)))
          prop :keep, Blog::Types::Hash
          prop :group, Blog::Types::ReviewGroup
          prop :from, Blog::Types::Date
          prop :to, Blog::Types::Date
          prop :days, Blog::Types::Array.of(Blog::Types::Date)
          prop :focused, Blog::Types::Bool, default: false

          def view_template
            Card(title: dotted(t(".title"), Blog::Helpers::Figures.count(tasks.size)), id: "review-done") do |card|
              card.side { SegmentedLinks(label: t(".group"), items: GROUPS.map { |name, text| switch(name, text) }) }
              if tasks.empty?
                Empty { t(@focused ? ".empty_day" : ".empty") }
              else
                listed
              end
            end
          end

          private

          def foot
            div(class: "review-foot") do
              a(class: "today-link", href: tasks_path) { t(".all", count: tasks.size) }
              Hint(inline: true) { t(".both") } if tag?
            end
          end

          def group(key, members)
            Group(name: name(key), href: tasks_path(query(key)), items: members, days: @days,
                  dated: :closed_on) do |task|
              Line(href: path(:admin_task, id: task.task_id), text: task.title)
            end
          end

          def groups = Grouping.by(tasks) { tag? ? it.tags : it.projects }

          def listed
            Capped(items: groups) { |key, members| group(key, members) }
            foot
          end

          def name(key)
            return t(tag? ? ".untagged" : ".no_project") if key.nil?

            tag? ? "##{key}" : key
          end

          def query(key)
            return if key.nil?

            return "tag:#{key}" if tag?

            Blog::Types::Normalized::Slug.call(key) { nil }&.then { "project:#{it}" }
          end

          def switch(name, text)
            place = { **@keep, group: (name unless name == TAG) }.compact

            { href: path(:admin_review, **place), text: t(text), current: name == @group }
          end

          def tag? = @group == TAG

          def tasks = @tasks ||= @done.values.flatten

          def tasks_path(query = nil)
            path(:admin_tasks, **{ filter: COMPLETED, from: @from.iso8601, to: @to.iso8601, q: query }.compact)
          end
        end
      end
    end
  end
end
