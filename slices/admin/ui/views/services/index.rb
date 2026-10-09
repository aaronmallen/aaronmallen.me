# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Services
        class Index < View
          include Components::Services

          prop :connect, Blog::Types::Instance(::Services::Definition).optional
          prop :connectable, Blog::Types::Array.of(Blog::Types::String)
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :pickable, Blog::Types::Array
          prop :refusal, Blog::Types::String.optional, default: nil
          prop :rows, Blog::Types::Array.of(Blog::Types::Instance(Structs::ServiceRow))
          prop :selected, Blog::Types::Instance(Structs::ServiceRow).optional

          def view_template
            SettingsHead(title: t(".heading"))
            div(class: "g-main") do
              list
              Card(class: "settings-side") { side }
            end
            Picker(definitions: @pickable) unless @pickable.empty?
          end

          private

          def connect_button
            Button(small: true, icon: "fa-solid fa-plus", data: { dialog_open: Picker::ID }) { t(".connect") }
          end

          def connectable?(definition) = @connectable.include?(definition.id)

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
              card.side do
                span(class: "settings-count") { summary }
                connect_button unless @pickable.empty?
              end
              Hint { t(".hint") }
              @rows.group_by { it.definition.group }.each { |name, rows| group(name, rows) }
            end
          end

          def side
            return Connect(definition: @connect, errors: @errors, refusal: @refusal) if @connect
            return Detail(row: @selected, connectable: connectable?(@selected.definition)) if @selected

            glance
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
