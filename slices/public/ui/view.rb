# frozen_string_literal: true

module Public
  module UI
    class View < Blog::UI::View
      include Components

      layout Layouts::Application

      private

      def head_wording(**values)
        content_for(:title, t(".title", **values))
        content_for(:description, t(".description", **values))
      end

      def linked_line(before, href, link, after, **attributes)
        p(**attributes) do
          plain(t(before))
          whitespace
          a(href:) { t(link) }
          plain(t(after))
        end
      end

      def page_head
        header(class: "hd") do
          span(class: "kicker") { t(".kicker") }
          h1 { t(".heading") }
          p(class: "ld") { t(".lede") }
        end
      end
    end
  end
end
