# frozen_string_literal: true

module Blog
  module UI
    module Components
      class Form < Component
        GET = "get"
        POST = "post"
        TOKEN_FIELD = Hanami::Action::CSRFProtection::CSRF_TOKEN.to_s

        prop :method, Blog::Types::String.enum(GET, POST), default: POST
        prop? :token, Blog::Types::String.optional
        prop :attributes, Blog::Types::Hash, :**

        def view_template
          form(method: @method, **@attributes) do
            input(type: "hidden", name: TOKEN_FIELD, value: token) unless @method == GET
            yield if block_given?
          end
        end

        private

        def token = Phlex::Hanami::Props::UNSET.equal?(@token) ? csrf_token : @token
      end
    end
  end
end
