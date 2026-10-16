# frozen_string_literal: true

module Admin
  module UI
    module Components
      class BulkTags < Component
        TAG = "tag"
        UNTAG = "untag"

        prop :menu, Blog::Types::Instance(ContextMenu)
        prop :action, Blog::Types::String
        prop :fields, Blog::Types::Hash
        prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :held, Blog::Types::Array.of(Blog::Types::String)
        prop :invalid, Blog::Types::String

        def view_template
          @menu.sub(t(".add"), icon: "fa-solid fa-tag") do
            @tags.each { tag(TAG, it.name) }
            @menu.separator unless @tags.empty?
            new_tag
          end
          return if @held.empty?

          @menu.sub(t(".remove"), icon: :close) { @held.each { tag(UNTAG, it) } }
        end

        private

        def new_tag
          fields = { **@fields, act: TAG }
          pattern = ContextMenu::TAG_PATTERN

          @menu.field(t(".new"), action: @action, name: TAG, pattern:, invalid: @invalid, fields:, suggest: @tags)
        end

        def tag(act, name)
          @menu.post("#{Tag::PREFIX}#{name}", action: @action, fields: { **@fields, act:, tag: name })
        end
      end
    end
  end
end
