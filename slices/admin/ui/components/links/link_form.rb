# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Links
        class LinkForm < Component
          prop :link, Blog::Types::Instance(ROM::Struct)
          prop :check, Blog::Types::Instance(ROM::Struct).optional, default: nil
          prop :values, Blog::Types::Hash.optional, default: nil
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def self.check_id(link) = "#{scope(link)}-check"

          extend ShareIds

          SCOPE = "link"

          def view_template
            markdown = Helpers::ShareLink.markdown(name, short)

            ShareSummary(kind: :link, name:, link: short, markdown:) do |summary|
              summary.meta { meta }
              destination_check
            end
            edit_form
            delete_form
            check_form
          end

          private

          def check_form = Form(id: self.class.check_id(@link), action: path(:admin_check_link, id: @link.id))

          def date(time, format) = l(Blog::TimeZone.local_date(time), format:)

          def delete_form
            Form(
              id: self.class.delete_id(@link), action: path(:admin_delete_link, id: @link.id),
              data: { morph: true, confirm: t(".confirm_delete", link: bare_url(short)) },
            )
          end

          def destination_check
            h3(class: "file-drawer-head") { t(".check") }
            Posts::LinkCheckRow(
              url: @link.destination, text: host, check: @check, published: true, form: self.class.check_id(@link),
            )
          end

          def edit_form
            action = path(:admin_update_link, id: @link.id)

            Form(id: self.class.form_id(@link), action:, class: "form-stack") { fields }
          end

          def field(name, label, hint, **)
            Field(label:, name:, errors: @errors, error: FieldError, scope:) do |control, field|
              Input(**control, name: "link[#{name}]", value: values[name], autocomplete: "off", **)
              field.after { Hint { hint } }
            end
          end

          def fields
            bare = bare_url(short)

            field(:destination, t(".destination"), t(".destination_hint", link: bare), inputmode: "url")
            field(:code, t(".code"), t(".code_hint", host: Helpers::ShareLink.host), spellcheck: "false")
            field(:title, t(".title"), t(".title_hint"), placeholder: host)
          end

          def host = Helpers::ShareLink.domain(@link.destination)

          def meta
            span { t(".clicks", count: @link.click_count, clicks: Blog::Helpers::Figures.count(@link.click_count)) }
            span { t(".made", on: date(@link.created_at, :long)) }
            span { t(".last_clicked", on: date(@link.last_clicked_at, :medium)) } if @link.last_clicked_at
          end

          def name = Helpers::ShareLink.link_name(@link)

          def scope = self.class.scope(@link)

          def short = Helpers::ShareLink.for(@link.code)

          def values = @values || { destination: @link.destination, code: @link.code, title: @link.title.to_s }
        end
      end
    end
  end
end
