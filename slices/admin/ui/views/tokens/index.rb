# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tokens
        class Index < View
          include Components::Tokens

          MINTED = "minted_token"
          SCOPES = [Blog::Types::OAuthScope["read"]].freeze

          prop :errors, Blog::Types::Hash
          prop :expires_on, Blog::Types::String, default: Blog::Constants::EMPTY_STRING
          prop :minted, Blog::Types::String.optional
          prop :name, Blog::Types::String
          prop :scopes, Blog::Types::Array.of(Blog::Types::String), default: SCOPES
          prop :tokens, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            SettingsHead(title: t(".heading"))
            div(class: "g-main") do
              live
              Card(title: t(".mint"), class: "settings-side") do
                Mint(name: @name, scopes: @scopes, expires_on: @expires_on, errors: @errors)
              end
            end
          end

          private

          def live
            Card(title: t(".live"), data: { key_list: true }) do |card|
              card.side { span(class: "settings-count") { t(".count", count: @tokens.size) } }
              Minted(value: @minted) if @minted
              @tokens.empty? ? Empty { t(".empty") } : @tokens.each { Row(token: it) }
            end
          end
        end
      end
    end
  end
end
