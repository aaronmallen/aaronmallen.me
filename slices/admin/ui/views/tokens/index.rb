# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tokens
        class Index < View
          include Components::Tokens

          MINTED = "minted_token"

          def initialize(errors:, minted:, name:, tokens:)
            super()
            @errors = errors
            @minted = minted
            @name = name
            @tokens = tokens
          end

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @tokens.size))

            Minted(value: @minted) if @minted
            Card(title: t(".mint")) { Mint(name: @name, errors: @errors) }
            Card(title: t(".live")) do
              next Empty { t(".empty") } if @tokens.empty?

              @tokens.each { Row(token: it) }
            end
          end
        end
      end
    end
  end
end
