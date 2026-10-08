# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class Details < Component
          FIELDS = %i[slug tags publish_at og_title og_image_url canonical_url syndication_body].freeze
          ID = "post-details"

          prop :post, Blog::Types::Instance(ROM::Struct).optional
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash
          prop :notes, Blog::Types::Hash
          prop :published, Blog::Types::Bool
          prop :scheduling, Blog::Types::Bool
          prop :syndication, Blog::Types::Hash
          prop :webmentions, Blog::Types::Hash

          def view_template
            Dialog(**dialog_attributes) do |dialog|
              dialog.foot { foot }

              Publishing(values: @values, errors: @errors, published: @published, scheduling: @scheduling)
              Seo(values: @values, errors: @errors)
              Syndication(errors: @errors, **@syndication)
              Webmentions(**@webmentions)
              EditNotes(**@notes)
            end
          end

          private

          def delete_button
            Button(
              variant: :warn, small: true, type: "submit", form: DeleteForm::ID, icon: "fa-regular fa-trash-can",
            ) { t(".delete") }
          end

          def dialog_attributes
            {
              id: ID, title_id: "#{ID}-title", title: t(".title"), class: "wide post-details", hidden: false,
              open: open?, data: { dialog: true },
            }
          end

          def foot
            delete_button if @post
            Button(variant: :pri, small: true, data: { dialog_close: true }) do
              t(".done")
            end
          end

          def open? = FIELDS.intersect?(@errors.keys) || @notes[:noting].any?
        end
      end
    end
  end
end
