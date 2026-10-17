# frozen_string_literal: true

module Public
  module UI
    module Views
      module Tags
        class Show < View
          include Components::Posts

          DESCRIPTION_LIMIT = Posts::Show::DESCRIPTION_LIMIT

          prop :tag, Blog::Types::String
          prop :description, Blog::Types::String.optional
          prop :posts, Blog::Types::Instance(Blog::Structs::Paged)
          prop :projects, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          include Deps["settings"]

          def view_template
            page_meta

            section do
              header(class: "hd") do
                h1 { t(".heading", tag: @tag) }
                described
              end
              writing
              projects
            end
          end

          private

          def described
            return unless @description

            html = ::Markdown::Note.to_html(@description, origin: settings.site_origin).strip
            div(class: "ld prose") { raw(safe(html)) }
          end

          def page_meta
            content_for(:title, t(".title", tag: @tag))
            content_for(:description, @description ? summary : t(".description", tag: @tag))
            content_for(:canonical, url(:tag, tag: @tag, **@posts.query))
            content_for(:feed, path(:tag_feed, tag: @tag)) unless @posts.rows.empty?
          end

          def projects
            return if @projects.empty?

            h2(class: "kicker kt") { t(".projects") }
            ProjectGrid(projects: @projects)
          end

          def summary = Blog::Helpers::Truncation.fit(::Markdown.to_text(@description), limit: DESCRIPTION_LIMIT)

          def writing
            return if @posts.rows.empty?

            h2(class: "kicker") { t(".writing") }
            List(posts: @posts.rows)
            Pager(page: @posts, route: :tag, params: { tag: @tag })
          end
        end
      end
    end
  end
end
