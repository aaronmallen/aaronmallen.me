# frozen_string_literal: true

module Admin
  module UI
    module Components
      class AttentionMore < Component
        KINDS = Blog::Types::AttentionKind
        BROKEN = Blog::Types::PostFilter["broken"]
        DRAFT = Blog::Types::PostFilter["draft"]
        SOMEDAY = Blog::Types::TaskTab["someday"]
        TODAY = Blog::Types::TaskTab["today"]

        prop :more, Blog::Types::Hash.map(KINDS, Blog::Types::Integer)

        def view_template
          @more.each do |kind, count|
            TodayLine(label: t([".kinds", kind].join(".")), href: href(kind), warn: true) { t(".more", count:) }
          end
        end

        private

        def href(kind)
          case kind
            when KINDS["broken_link"] then path(:admin_posts, status: BROKEN)
            when KINDS["carried"] then path(:admin_tasks, filter: TODAY)
            when KINDS["draft"] then path(:admin_posts, status: DRAFT)
            when KINDS["lapsing"] then Helpers::ServiceTab.services(routes)
            when KINDS["new_device"] then path(:admin_security)
            when KINDS["someday"] then path(:admin_tasks, filter: SOMEDAY)
            else path(:admin_journal)
          end
        end
      end
    end
  end
end
