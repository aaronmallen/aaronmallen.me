# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tokens
        class Index < View
          include Components::Tokens

          MINTED = "minted_token"

          prop :errors, Blog::Types::Hash
          prop :minted, Blog::Types::String.optional
          prop :name, Blog::Types::String
          prop :tokens, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @tokens.size))

            Minted(value: @minted) if @minted
            Card(title: t(".mint")) { Mint(name: @name, errors: @errors) }
            Card(title: t(".live"), data: { key_list: true }) do
              next Empty { t(".empty") } if @tokens.empty?

              @tokens.each { Row(token: it) }
            end
          end
        end
      end
    end
  end
end
