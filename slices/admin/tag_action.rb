# auto_register: false
# frozen_string_literal: true

module Admin
  class TagAction < Action
    TOASTS = "record_tags.toasts"

    def handle(request, response)
      tag = Blog::Types::Nullable::Tag[request.params[:tag]]

      toast(response, "#{TOASTS}.#{outcome(record_id(request), tag)}", tag:)
      response.redirect_to(auth_session(request).admin_return_path(request.params[:return_to]) || list_path)
    end

    private

    def outcome(id, tag)
      return Blog::Contract::BLANK if tag.nil?
      return Blog::Contract::FORMAT unless Blog::Types::Tag.valid?(tag)

      case retag(id, tag)
        in Success(_) then self.class::DONE
        in Failure(:not_found) then halt 404
        else halt 500
      end
    end
  end
end
