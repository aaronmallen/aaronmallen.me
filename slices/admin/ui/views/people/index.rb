# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class Index < View
          include Components::People

          ALL = Blog::Types::ContactShow.values.first
          LIVE_TABLES = %w[people service_connections].freeze
          SEARCH_ID = "contacts-search"
          SHOWS = Blog::Types::ContactShow.values.to_h { [it, ".shows.#{it}"] }.freeze

          prop :people, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :list, Blog::Types::Hash
          prop :count, Blog::Types::Integer
          prop :labels, Blog::Types::Array.of(Blog::Types::String)
          prop :searchable, Blog::Types::Array.of(Blog::Types::NetworkName)
          prop :synced_at, Blog::Types::Time.optional
          prop :sync_failed, Blog::Types::Bool

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            PageHead(title: t(".heading"), sub: "#{t('.lede', count: @count)} · #{synced}") { actions }
            div(class: ("g-main" if @searchable.any?)) do
              div(class: "stack") do
                filters
                rows
              end
              Finder(networks: @searchable) if @searchable.any?
            end
          end

          private

          def actions
            ButtonForm(action: path(:admin_sync_people), label: t(".sync"), icon: "fa-solid fa-arrows-rotate")
            CreateLink(href: path(:admin_new_person), label: t(".new"))
          end

          def filtered? = @list.values_at(:query, :label).any? || @list[:show] != ALL

          def filters
            div(class: "contacts-filters") do
              search
              SegmentedLinks(label: t(".show"), items: SHOWS.map { |show, key| show_link(show, key) })
              labels if @labels.any?
            end
          end

          def label_link(label)
            on = label == @list[:label]

            a(class: "search-kind", href: list_path(label: (label unless on)), aria: { current: ("page" if on) }) do
              "##{label}"
            end
          end

          def labels
            nav(class: "search-kinds contacts-labels", aria: { label: t(".labels") }) do
              @labels.each { label_link(it) }
            end
          end

          def list_path(**changes)
            query = { q: @list[:query], show: @list[:show], label: @list[:label] }.merge(changes)
            query.delete(:show) if query[:show] == ALL

            path(:admin_contacts, **query.compact)
          end

          def rows
            return Empty { t(filtered? ? ".no_match" : ".empty") } if @people.empty?

            Card(data: { key_list: true }) { @people.each { Row(person: it) } }
          end

          def search
            AutoForm(action: path(:admin_contacts), role: "search", class: "contacts-search") do
              input(type: "hidden", name: "show", value: @list[:show]) unless @list[:show] == ALL
              input(type: "hidden", name: "label", value: @list[:label]) if @list[:label]
              SearchField(
                id: SEARCH_ID, label: t(".search"), name: "q", value: @list[:query], placeholder: t(".placeholder"),
              )
            end
          end

          def show_link(show, key) = { text: t(key), href: list_path(show:), current: show == @list[:show] }

          def synced
            return t(".sync_failed") if @sync_failed
            return t(".never_synced") unless @synced_at

            t(".synced", at: l(Blog::TimeZone.local(@synced_at), format: :short))
          end
        end
      end
    end
  end
end
