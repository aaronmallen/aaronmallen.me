# frozen_string_literal: true

module Admin
  module UI
    module Views
      module TaskRules
        class Index < View
          include Components::TaskRules

          BLANK = {
            errors: Blog::Constants::EMPTY_HASH,
            pattern: Blog::Constants::EMPTY_STRING,
            provider: Blog::Types::TaskSourceProvider["github"],
            tags: Blog::Constants::EMPTY_STRING,
            projects: Blog::Constants::EMPTY_ARRAY,
          }.freeze
          LIVE_TABLES = %w[projects task_rule_projects task_rule_tags task_rules].freeze
          TYPED = %i[pattern provider tags].freeze

          prop :adding, Blog::Types::Hash
          prop :editing, Blog::Types::Hash.optional
          prop :rules, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :projects, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def self.typed(params)
            { **TYPED.to_h { [it, Blog::Types::Text[params[it]]] }, projects: Array(params[:projects]).map(&:to_s) }
          end

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            SettingsHead(title: t(".heading"))
            div(class: "g-main") do
              list
              Card(title: t(".add"), class: "settings-side") do
                Capture(**@adding, choices: @projects, tag_choices: @tags)
              end
            end
          end

          private

          def list
            note = t(".count", count: @rules.size)

            Card(title: t(".title"), note:, note_class: "settings-count", blurb: t(".sub"), data: { key_list: true }) do
              rows
              Hint { t(".note") }
            end
          end

          def rows
            return Empty { t(".empty") } if @rules.empty?

            @rules.each { Row(rule: it, editing: @editing, choices: @projects, tag_choices: @tags) }
          end
        end
      end
    end
  end
end
