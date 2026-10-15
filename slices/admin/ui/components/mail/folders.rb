# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Folders < Component
          ACT = Blog::Types::MessageBulkAction
          FOLDER = Blog::Types::MailFolder
          DROPS = {
            FOLDER["inbox"] => ACT["inbox"],
            FOLDER["starred"] => ACT["star"],
            FOLDER["all"] => ACT["archive"],
            FOLDER["spam"] => ACT["spam"],
            FOLDER["trash"] => ACT["trash"],
          }.freeze
          ICONS = {
            FOLDER["inbox"] => "fa-solid fa-inbox",
            FOLDER["updates"] => "fa-regular fa-bell",
            FOLDER["starred"] => "fa-regular fa-star",
            FOLDER["snoozed"] => "fa-regular fa-clock",
            FOLDER["sent"] => "fa-regular fa-paper-plane",
            FOLDER["drafts"] => "fa-regular fa-file-lines",
            FOLDER["all"] => "fa-regular fa-envelope-open",
            FOLDER["spam"] => :ban,
            FOLDER["trash"] => :trash,
          }.freeze
          NAMES = FOLDER.values.to_h { [it, "ui.components.mail.folders.names.#{it}"] }.freeze

          prop :list, Blog::Types::Hash
          prop :counts, Blog::Types::Hash
          prop :labels, Blog::Types::Hash
          prop :chips, Blog::Types::Hash

          def view_template
            nav(class: "mail-folders", aria: { label: t(".label") }, data: { mail_many: t(".many") }) do
              ICONS.each do |folder, icon|
                link(folder, drop: { mail_drop: DROPS[folder] }) do
                  Icon(icon)
                  name_and_count(t(NAMES.fetch(folder)), @counts.fetch(folder, 0))
                end
              end
              @chips.each { |account, chip| group(account, chip, @labels[account]) if @labels[account]&.any? }
            end
          end

          private

          def group(account, chip, labels)
            div(class: "mail-folder-group") do
              p(class: "mail-folder-head") { @list[:account] ? t(".labels") : Account(chip:) }
              labels.each do |(name, count)|
                drop = { mail_drop: ACT["label"], mail_label: "#{account}:#{name}" }
                link("#{Helpers::MailList::LABEL}#{name}", chip.last, drop:) do
                  span(class: "mail-dot", aria: { hidden: "true" })
                  name_and_count(name, count)
                end
              end
            end
          end

          def link(folder, tone = nil, drop:, &)
            on = folder == @list[:folder]
            a(href: path(:admin_mail, **@list, folder:), class: ["mail-folder", tone, ("on" if on)],
              aria: { current: ("page" if on) }, data: drop.compact, &)
          end

          def name_and_count(name, count)
            span(class: "mail-folder-name") { name }
            span(class: "mail-folder-count") { count.to_s } if count.positive?
          end
        end
      end
    end
  end
end
