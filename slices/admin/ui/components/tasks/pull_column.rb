# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class PullColumn < Component
          ORIGIN = Blog::Types::TaskOrigin["tasks"]

          prop :counts, Blog::Types::Hash
          prop :pool, Blog::Types::String
          prop(
            :pools,
            Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))),
          )

          def view_template
            title = t(".title")

            Card(as: :aside, title:, class: "task-pull", aria: { label: title }, data: { key_list: true }) do
              Pools(counts: @counts, origin: ORIGIN, pool: @pool, pools: @pools)
            end
          end
        end
      end
    end
  end
end
