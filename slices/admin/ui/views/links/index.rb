# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Links
        class Index < View
          include Components::Links

          LIVE_TABLES = %w[short_codes short_link_checks short_links].freeze
          FAILING = Blog::Types::ShortLinkFilter["failing"]
          FILTERS = Blog::Types::ShortLinkFilter.values.to_h { [it, "ui.views.links.index.filters.#{it}"] }.freeze
          SEARCH_ID = "links-search"
          SORTS = Blog::Types::ShortLinkSort.values.to_h { [it, "ui.views.links.index.sorts.#{it}"] }.freeze

          prop :again, Blog::Types::Instance(ROM::Struct).optional
          prop :checks, Blog::Types::Hash
          prop :count, Blog::Types::Integer
          prop :errors, Blog::Types::Hash
          prop :links, Blog::Types::Instance(Blog::Structs::Paged)
          prop :list, Blog::Types::Hash
          prop :totals, Blog::Types::Hash
          prop :values, Blog::Types::Hash

          def view_template
            content_for(:live_tables, LIVE_TABLES)
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

          def empty
            return ".empty" if @totals[:count].zero?

            failing? && !search ? ".no_failing" : ".no_match"
          end

          def failing? = filter == FAILING

          def filter = @list[:filter]

          def filters
            counts = { "all" => @totals[:count], FAILING => @totals[:failing] }
            counts.to_h { |value, count| [value, t(FILTERS.fetch(value), count:)] }
          end

          def list
            Card(empty: (t(empty) if @links.rows.empty?), class: "link-list") { @links.rows.each { row(it) } }
            @links.rows.each do |link|
              ShareDrawer(form: LinkForm, record: link, kind: :link) { LinkForm(link:, check: @checks[link.id]) }
            end
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

          def query = { sort:, filter: (filter if failing?), search: }.compact

          def row(link) = Row(link:, check: @checks[link.id])

          def search = @list[:search]

          def search_form
            AutoForm(action: path(:admin_links), role: "search", class: "file-search") do
              input(type: "hidden", name: "sort", value: sort)
              SearchField(
                id: SEARCH_ID, label: t(".search"), name: "search", value: search, placeholder: t(".placeholder"),
              )
              Hint { t(".matches", count: @count) } if search
              SegmentedControl(label: t(".filter"), name: "filter", options: filters, selected: filter)
            end
          end

          def sort = @list[:sort]

          def sort_form
            FilterSwitch(
              action: path(:admin_links), name: "sort", options: SORTS.transform_values { t(it) }, selected: sort,
              label: t(".sort"), keep: { filter: (filter if failing?), search: },
            )
          end

          def sub
            lede = t(
              ".lede",
              count: @totals[:count], host: Helpers::ShareLink.host,
              clicks: t(".clicks", count: @totals[:clicks], clicks: Blog::Helpers::Figures.count(@totals[:clicks])),
            )
            failing = @totals[:failing]

            "#{lede} #{failing.positive? ? t('.lede_failing', count: failing) : t('.lede_fine')}"
          end

          def typed(name) = { name: "link[#{name}]", value: @values[name], autocomplete: "off" }
        end
      end
    end
  end
end
