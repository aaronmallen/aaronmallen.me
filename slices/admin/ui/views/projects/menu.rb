# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Projects
        class Menu < View
          GITHUB = "https://github.com/%s"
          REPO = "fa-brands fa-github"

          layout nil

          prop :project, Blog::Types::Instance(ROM::Struct)
          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: @project.name, return_to: @return_to) do |menu|
              menu.link(t(".open_board"), href: act(:admin_project), icon: "fa-solid fa-table-columns")
              menu.link(t(".edit"), href: act(:admin_edit_project), icon: :edit)
              opens(menu)
              menu.separator
              tags(menu)
              copy_repo(menu) if repo?
              menu.separator
              change(menu)
            end
          end

          private

          def act(route) = path(route, id: @project.id)

          def change(menu)
            if @project.archived?
              menu.post(t(".restore"), action: act(:admin_restore_project), icon: "fa-solid fa-rotate-left")
            else
              menu.post(t(".archive"), action: act(:admin_archive_project), icon: "fa-solid fa-box-archive")
            end
          end

          def copy_repo(menu)
            menu.copy(t(".copy_repo"), text: @project.repo, copied: t(".copied_repo"), icon: :copy)
          end

          def opens(menu)
            menu.link(t(".open_repo"), href: format(GITHUB, @project.repo), icon: REPO, outbound: true) if repo?
            menu.link(t(".open_site"), href: @project.url, icon: :outbound, outbound: true) if written?(@project.url)
          end

          def repo? = written?(@project.repo)

          def tags(menu)
            names = @project.tags.map(&:name)
            invalid = t("record_tags.toasts.format")

            menu.tags(t(".tags"), names:, tags: @tags, new_tag: t(".new_tag"), invalid:) do |name, on|
              tag = name ? { tag: name } : Blog::Constants::EMPTY_HASH

              { action: act(on ? :admin_untag_project : :admin_tag_project), fields: tag }
            end
          end
        end
      end
    end
  end
end
