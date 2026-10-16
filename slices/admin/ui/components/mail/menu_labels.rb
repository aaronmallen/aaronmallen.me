# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class MenuLabels < Component
          ACT = Blog::Types::MessageBulkAction

          prop :menu, Blog::Types::Instance(ContextMenu)
          prop :thread, Blog::Types::Instance(ROM::Struct)
          prop :account, Blog::Types::Instance(ROM::Struct)
          prop :labels, Blog::Types::Array.of(Blog::Types::String)
          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :fields, Blog::Types::Hash

          def view_template
            @menu.sub(t(".label"), icon: "fa-solid fa-tag", hint: (held.size.to_s unless held.empty?)) do
              @labels.each { check(it) }
              new_label
            end
          end

          private

          def action = path(:admin_bulk_mail)

          def check(name)
            on = held.include?(name)
            tag = @thread.tags.any? { it.name == name }
            fields = on ? { act: ACT["untag"], tag: name } : { act: ACT["label"], label: "#{@account.id}:#{name}" }

            @menu.check("#{Tag::PREFIX}#{name}", on:, action:, fields: { **@fields, **fields }, disabled: on && !tag)
          end

          def held = [*@thread.mail_labels, *@thread.tags].map(&:name).uniq

          def new_label
            @menu.separator unless @labels.empty?
            fields = { **@fields, act: ACT["tag"] }
            pattern = ContextMenu::TAG_PATTERN

            @menu.field(t(".new"), action:, name: "tag", fields:, pattern:, invalid: t(".invalid"), suggest: @tags)
          end
        end
      end
    end
  end
end
