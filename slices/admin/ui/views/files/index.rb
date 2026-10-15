# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Files
        class Index < View
          include Components::Files

          FILTERS = Blog::Types::ShareFilter.values.to_h { [it, "ui.views.files.index.#{it}"] }.freeze
          FILES_ID = "files-upload"
          LIVE_TABLES = %w[share_group_files share_groups short_codes].freeze
          SEARCH_ID = "files-search"

          prop :count, Blog::Types::Integer
          prop :groups, Blog::Types::Array
          prop :group_options, Blog::Types::Hash
          prop :list, Blog::Types::Hash
          prop :shares, Blog::Types::Instance(Blog::Structs::Paged)
          prop :totals, Blog::Types::Hash

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            PageHead(title: t(".heading"), sub:) do
              filter_form
              BulkToggle(form: Bulk::ID) unless @shares.rows.empty?
            end
            upload_form
            search_form
            listing
            Pager(page: @shares, route: :admin_files, params: query)
          end

          private

          def empty = (@totals[:count] + @totals[:groups]).zero? ? ".empty" : ".no_match"

          def filter = @list[:filter]

          def filter_form
            FilterSwitch(
              action: path(:admin_files), name: "kind", options: FILTERS, selected: filter, label: t(".filter"),
              keep: { search: },
            )
          end

          def grid
            div(class: "file-bulk") do
              Bulk(groups: @group_options)
              div(class: "file-grid") do
                @groups.each { GroupTile(group: it) }
                @shares.rows.each { Tile(share: it) }
              end
            end
            @groups.each { |group| ShareDrawer(form: GroupForm, record: group, kind: :group) { GroupForm(group:) } }
            @shares.rows.each { |share| ShareDrawer(form: ShareForm, record: share, kind: :file) { ShareForm(share:) } }
          end

          def listing = @shares.rows.empty? && @groups.empty? ? Card { Empty { t(empty) } } : grid

          def query = { kind: filter, search: }.compact

          def search = @list[:search]

          def search_form
            AutoForm(action: path(:admin_files), role: "search", class: "file-search") do
              input(type: "hidden", name: "kind", value: filter)
              SearchField(
                id: SEARCH_ID, label: t(".search"), name: "search", value: search, placeholder: t(".placeholder"),
              )
              Hint { t(".matches", count: @count) } if search
            end
          end

          def sub
            t(
              ".lede",
              count: @totals[:count], host: Helpers::ShareLink.host,
              size: Blog::Helpers::Figures.size(@totals[:bytes]),
            )
          end

          def submit
            Button(type: "submit", small: true, variant: :pri, icon: "fa-solid fa-arrow-up-from-bracket") do
              t(".upload")
            end
          end

          def upload_form
            Form(
              action: path(:admin_create_files), enctype: "multipart/form-data", class: "file-drop",
              data: {
                file_drop: "", file_drop_busy: t(".uploading"), file_drop_copied: t(".copied"),
                file_drop_failed: t(".upload_failed"),
              },
            ) do
              Icon("fa-solid fa-cloud-arrow-up")
              label(for: FILES_ID, data: { file_drop_status: true }) { t(".drop") }
              input(id: FILES_ID, class: "file-drop-input", type: "file", name: "files[]", multiple: true)
              Checkbox(label: t(".group"), name: "group")
              noscript { submit }
            end
          end
        end
      end
    end
  end
end
