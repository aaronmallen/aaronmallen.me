# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class ContributorFilter < Component
          ANY = Blog::Constants::EMPTY_STRING
          KINDS = { ANY => ".anyone", "owner" => ".owner", "agent" => ".agents" }.freeze
          Pick = Data.define(:list, :label, :any)
          PICKS = {
            agent: Pick.new(list: :agents, label: ".agent", any: ".any_agent"),
            model: Pick.new(list: :models, label: ".model", any: ".any_model"),
          }.freeze

          def self.query(credits)
            { contributor: credits[:contributors], agent: credits[:agents], model: credits[:models] }
              .transform_values { it.to_a.first }.compact
          end

          prop :credits, Blog::Types::Hash
          prop :choices, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::Array.of(Blog::Types::String))

          def view_template
            Field(label: t(".label")) do
              SegmentedControl(label: t(".label"), name: "contributor", options: kinds, selected: picked[:contributor])
            end
            PICKS.each { |name, kind| pick(name, kind) }
          end

          private

          def kinds = KINDS.transform_values { t(it) }

          def options(kind, names) = { ANY => t(kind.any), **names.to_h { [it, it] } }

          def pick(name, kind)
            names = [*@choices.fetch(kind.list), *picked[name]].uniq
            return if names.empty?

            Field(label: t(kind.label), id: "review-#{name}") do |control|
              Select(**control, name: name.to_s, options: options(kind, names), selected: picked[name] || ANY)
            end
          end

          def picked = @picked ||= self.class.query(@credits)
        end
      end
    end
  end
end
