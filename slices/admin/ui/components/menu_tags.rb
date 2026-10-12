# frozen_string_literal: true

module Admin
  module UI
    module Components
      class MenuTags < Component
        prop :menu, Blog::Types::Instance(ContextMenu)
        prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :names, Blog::Types::Array.of(Blog::Types::String)
        prop :tag_path, Blog::Types::String
        prop :untag_path, Blog::Types::String

        def view_template
          @menu.sub(t(".tags"), icon: "fa-solid fa-tag", hint: (@names.size.to_s unless @names.empty?)) do
            @tags.each { tick(it.name) }
            @menu.separator unless @tags.empty?
            new_tag
          end
        end

        private

        def new_tag
          pattern = ContextMenu::TAG_PATTERN

          @menu.field(t(".new_tag"), action: @tag_path, name: "tag", pattern:, invalid: t("record_tags.toasts.format"))
        end

        def tick(name)
          on = @names.include?(name)

          @menu.check("#{Tag::PREFIX}#{name}", on:, action: on ? @untag_path : @tag_path, fields: { tag: name })
        end
      end
    end
  end
end
