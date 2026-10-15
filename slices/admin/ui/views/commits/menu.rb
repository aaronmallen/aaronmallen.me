# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Commits
        class Menu < View
          layout nil

          prop :commit, Blog::Types::Instance(ROM::Struct)

          def view_template
            ContextMenu(label: "#{sha} · #{subject}") do |menu|
              opens(menu)
              menu.separator
              menu.copy(t(".copy_sha"), text: @commit.sha, copied: t(".copied_sha"), icon: :copy, hint: sha)
              menu.copy(t(".copy_message"), text: subject, copied: t(".copied_message"), icon: :copy)
            end
          end

          private

          def github = format(Show::GITHUB_URL, @commit.repo, @commit.sha)

          def opens(menu)
            menu.link(t(".open"), href: path(:admin_commit, id: @commit.id), icon: "fa-regular fa-folder-open")
            menu.link(t(".github"), href: github, icon: "fa-brands fa-github", outbound: true)
          end

          def sha = Admin::Short.sha(@commit.sha)

          def subject = Helpers::CommitMessage.subject(@commit.message)
        end
      end
    end
  end
end
