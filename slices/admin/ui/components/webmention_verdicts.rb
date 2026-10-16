# frozen_string_literal: true

module Admin
  module UI
    module Components
      class WebmentionVerdicts < Component
        VARIANTS = {
          Blog::Types::WebmentionVerdict["approved"] => nil,
          Blog::Types::WebmentionVerdict["ignored"] => :gh,
          Blog::Types::WebmentionVerdict["spam"] => :warn,
        }.freeze
        IGNORED = Blog::Types::WebmentionVerdict["ignored"]
        SPAM = Blog::Types::WebmentionVerdict["spam"]

        prop :actions, Blog::Types::Hash
        prop :kept, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
        prop :icons, Blog::Types::Bool, default: true

        def view_template
          VARIANTS.each { |verdict, variant| verdict(verdict, variant) if @actions.key?(verdict) }
        end

        private

        def reason = Input(name: "reason", placeholder: t(".reason"), aria: { label: t(".reason") })

        def verdict(verdict, variant)
          spam = verdict == SPAM

          Form(action: @actions.fetch(verdict), data: { morph: true }, class: ("wm-spam" if spam)) do
            HiddenFields(values: @kept)
            reason if spam
            WebmentionVerdict(verdict:, variant:, icon: @icons && verdict != IGNORED)
          end
        end
      end
    end
  end
end
