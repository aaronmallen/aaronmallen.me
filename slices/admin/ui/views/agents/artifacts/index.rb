# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Agents
        module Artifacts
          class Index < View
            include Components::Agents

            ICONS = {
              "plan" => "fa-solid fa-route", "spec" => "fa-solid fa-ruler-combined", "research" => "fa-solid fa-flask",
              "handoff" => "fa-solid fa-right-left", "notes" => "fa-regular fa-note-sticky",
              "review" => "fa-solid fa-magnifying-glass", "postmortem" => "fa-solid fa-heart-crack",
              "other" => "fa-regular fa-file",
            }.freeze
            LIVE_TABLES = %w[artifact_versions artifacts record_links].freeze
            SEARCH_ID = "artifacts-search"

            prop :artifacts, Blog::Types::Instance(Blog::Structs::Paged)
            prop :list, Blog::Types::Hash
            prop :counts, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer)
            prop :week, Blog::Types::Integer
            prop :current, Blog::Types::Hash
            prop :linked, Blog::Types::Hash

            def view_template
              content_for(:live_tables, LIVE_TABLES)
              PageHead(title: t(".heading"), sub: t(".lede", count: total, week: @week)) do
                CreateLink(href: path(:admin_new_artifact), label: t(".new_artifact"))
              end
              search_form
              types
              Card { rows }
              Pager(page: @artifacts, route: :admin_artifacts, params: query)
            end

            private

            def query = { type: @list[:type], search: @list[:text] }.compact

            def rows
              return Empty { t(@list.values.any? ? ".no_match" : ".empty") } if @artifacts.rows.empty?

              @artifacts.rows.each do |artifact|
                ArtifactRow(artifact:, current: @current.fetch(artifact.id), links: @linked.fetch(artifact.id, 0))
              end
            end

            def search_form
              AutoForm(action: path(:admin_artifacts), role: "search", class: "file-search") do
                HiddenFields(values: { type: @list[:type] })
                SearchField(
                  id: SEARCH_ID, label: t(".search"), name: "search", value: @list[:text],
                  placeholder: t(".placeholder"),
                )
                noscript { Button(type: "submit", small: true) { t(".find") } }
              end
            end

            def total = @counts.values.sum

            def type_link(type, text, count)
              a(
                class: "search-kind", href: path(:admin_artifacts, **{ type:, search: @list[:text] }.compact),
                aria: { current: ("page" if type == @list[:type]) },
              ) do
                Icon(ICONS.fetch(type)) if type
                plain text
                whitespace
                span { count.to_s }
              end
            end

            def types
              nav(class: "search-kinds", aria: { label: t(".type") }) do
                type_link(nil, t(".all"), total)
                @counts.each { |type, count| type_link(type, type, count) }
              end
            end
          end
        end
      end
    end
  end
end
