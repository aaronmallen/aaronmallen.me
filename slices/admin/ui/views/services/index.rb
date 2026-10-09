# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Services
        class Index < View
          include Components::Services

          prop :available, Blog::Types::Array
          prop :rows, Blog::Types::Array.of(Blog::Types::Instance(Structs::ServiceRow))
          prop :selected, Blog::Types::Instance(Structs::ServiceRow).optional

          def view_template
            SettingsHead(title: t(".heading"))
            div(class: "g-main") do
              list
              Card(class: "settings-side") { @selected ? Detail(row: @selected) : glance }
            end
          end

          private

          def available
            return if @available.empty?

            div(class: "svc-group") do
              p(class: "svc-group-label") { t(".available") }
              @available.each { Available(definition: it) }
            end
          end

          def failing = @rows.select { it.status == :failing }

          def glance
            h2(class: "card-title") { t(".glance") }
            if failing.empty?
              p(class: "settings-aside") { t(".all_answered") }
            else
              failing.each { SyncFailures(failures: it.failing_jobs.map { it[:failure] }) }
            end
            Hint { t(".pick_hint") }
          end

          def group(name, rows)
            div(class: "svc-group") do
              p(class: "svc-group-label") { t(".groups").fetch(name.to_sym) }
              rows.each { Row(row: it, selected: it == @selected) }
            end
          end

          def list
            Card(title: t(".connected"), data: { key_list: true }) do |card|
              card.side { span(class: "settings-count") { summary } }
              Hint { t(".hint") }
              @rows.group_by { it.definition.group }.each { |name, rows| group(name, rows) }
              available
            end
          end

          def summary
            count = t(".count", count: @rows.size)
            failing.empty? ? count : dotted(count, t(".failing", count: failing.size))
          end
        end
      end
    end
  end
end
