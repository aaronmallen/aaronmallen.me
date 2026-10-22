# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class Top < Component
          prop :person, Avatar::FIELDS
          prop :title, Blog::Types::String
          prop :sub, Blog::Types::String.optional, default: nil
          prop :labels, Blog::Types::Array.of(Blog::Types::String), default: -> { Blog::Constants::EMPTY_ARRAY }
          prop :back, Blog::Types::String
          prop :back_label, Blog::Types::String

          def view_template(&)
            content_for(:title, @title)
            BackLink(href: @back, variant: :gh, small: true, class: "contact-back") { @back_label }
            header(class: "contact-head") do
              Avatar(person: @person, large: true)
              div(class: "contact-head-text") { text }
              div(class: "contact-head-acts", &)
            end
          end

          private

          def labels = @labels.each { |label| span(class: "tag") { "##{label}" } }

          def text
            h1(class: "contact-head-title") { @title }
            p(class: "contact-head-sub") { @sub } if @sub
            div(class: "contact-head-labels") { labels } if @labels.any?
          end
        end
      end
    end
  end
end
