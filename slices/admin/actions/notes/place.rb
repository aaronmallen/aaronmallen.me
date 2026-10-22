# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      module Place
        REFUSALS = { [:parent_id, "inside"] => "inside", [:title, "taken"] => "taken" }.freeze
        TOASTS = "notes_page.toasts"

        private

        def back(request) = back_here(request) || routes.path(:admin_notes)

        def folder_at(request) = create_note_folder_path.call(request.params[:path]).fmap { it&.id }

        def moved_toast(response, path)
          path = Blog::Types::TrimmedText[path].split("/").map(&:strip).reject(&:empty?).join("/")
          path.empty? ? toast(response, "#{TOASTS}.moved_top") : toast(response, "#{TOASTS}.moved", path:)
        end

        def refused(request, response, errors)
          field, codes = errors.first
          toast(response, "#{TOASTS}.refused.#{REFUSALS.fetch([field, Array(codes).first], 'invalid')}")
          response.redirect_to(back(request))
        end
      end
    end
  end
end
