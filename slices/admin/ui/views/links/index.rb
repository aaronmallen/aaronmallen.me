# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Links
        class Index < View
          include Components::Links

          SEARCH_ID = "links-search"
          SORTS = Blog::Types::ShortLinkSort.values.to_h { [it, "ui.views.links.index.sorts.#{it}"] }.freeze

          prop :again, Blog::Types::Instance(ROM::Struct).optional
          prop :count, Blog::Types::Integer
          prop :errors, Blog::Types::Hash
          prop :links, Blog::Types::Instance(Blog::Structs::Paged)
          prop :list, Blog::Types::Hash
          prop :totals, Blog::Types::Hash
          prop :values, Blog::Types::Hash

          def view_template
            PageHead(title: t(".heading"), sub:) { sort_form }
            new_form
            search_form
            list
            Pager(page: @links, route: :admin_links, params: query)
          end

          private

          def again_hint
            input(type: "hidden", name: "link[again]", value: @values[:destination])
            Hint { t(".again", link: Helpers::ShareLink.bare(Helpers::ShareLink.for(@again.code))) }
          end

          def code_field
            Field(label: t(".code"), name: :code, errors: @errors, error: FieldError) do |control|
              div(class: "link-code") do
                span { "#{Helpers::ShareLink.host}/" }
                Input(**control, **typed(:code), spellcheck: "false", placeholder: t(".code_placeholder"))
              end
            end
          end

          def destination_field
            Field(label: t(".destination"), name: :destination, errors: @errors, error: FieldError) do |control|
              Input(**control, **typed(:destination), inputmode: "url", placeholder: t(".destination_placeholder"))
            end
          end

          def empty = @totals[:count].zero? ? ".empty" : ".no_match"

          def list
            Card(class: "link-list") { @links.rows.empty? ? Empty { t(empty) } : @links.rows.each { Row(link: it) } }
            @links.rows.each { |link| ShareDrawer(form: LinkForm, record: link, kind: :link) { LinkForm(link:) } }
          end

          def new_form
            Form(
              action: path(:admin_create_link), class: "link-new card",
              data: { link_form: "", link_form_copied: t(".copied") },
            ) do
              destination_field
              code_field
              Button(type: "submit", variant: :pri, icon: "fa-solid fa-link") { t(".shorten") }
              again_hint if @again
            end
          end

          def query = { sort:, search: }.compact

          def search = @list[:search]

          def search_form
            AutoForm(action: path(:admin_links), role: "search", class: "file-search") do
              input(type: "hidden", name: "sort", value: sort)
              SearchField(
                id: SEARCH_ID, label: t(".search"), name: "search", value: search, placeholder: t(".placeholder"),
              )
              Hint { t(".matches", count: @count) } if search
            end
          end

          def sort = @list[:sort]

          def sort_form
            FilterSwitch(
              action: path(:admin_links), name: "sort", options: SORTS, selected: sort, label: t(".sort"),
              keep: { search: },
            )
          end

          def sub
            t(
              ".lede",
              count: @totals[:count], host: Helpers::ShareLink.host,
              clicks: t(".clicks", count: @totals[:clicks], clicks: Blog::Helpers::Figures.count(@totals[:clicks])),
            )
          end

          def typed(name) = { name: "link[#{name}]", value: @values[name], autocomplete: "off" }
        end
      end
    end
  end
end
