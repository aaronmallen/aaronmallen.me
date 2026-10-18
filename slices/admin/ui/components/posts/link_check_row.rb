# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class LinkCheckRow < Component
          prop :url, Blog::Types::String
          prop :text, Blog::Types::String
          prop :check, Blog::Types::Instance(ROM::Struct).optional
          prop :published, Blog::Types::Bool
          prop :quiet, Blog::Types::Bool, default: false
          prop :form, Blog::Types::String, default: LinksDrawer::FORM
          prop :action, Blog::Types::String.optional, default: nil

          def view_template(&)
            ListItem(title: @text.empty? ? @url : @text, href: nil, sub: @url) do |item|
              item.meta { meta }
              check_button if @published
              yield if block_given?
              open_button
            end
          end

          private

          def check_button
            Button(
              small: true, type: "submit", form: @form, formaction: @action, name: "url", value: @url,
              icon: "fa-solid fa-rotate", label: t(@check ? ".check_again" : ".check_now", link: @url),
            )
          end

          def detail
            return span { t(@published ? ".added" : ".once_live") } unless @check

            span(class: "post-link-reason") { @check.reason } if failing?
            span { Stamped(text: t(".checked", at: Stamped::MARK), at: @check.checked_at) }
            span { t(".first_failed", on: first_failed) } if failing?
          end

          def failing? = @check&.reason

          def first_failed = l(Blog::TimeZone.local_date(@check.first_failed_at || @check.checked_at), format: :medium)

          def meta
            p(class: "li-sub post-link-meta") do
              LinkCheckPill(check: @check)
              detail unless @quiet
            end
          end

          def open_button
            Button(
              href: @url, small: true, variant: :gh, icon: :outbound, label: t(".open", link: @url),
              target: "_blank", rel: "noopener",
            )
          end
        end
      end
    end
  end
end
