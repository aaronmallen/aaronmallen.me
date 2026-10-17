# auto_register: false
# frozen_string_literal: true

module Admin
  class BulkAction < Action
    LONG = "long"
    REFUSALS = "bulk_refusals."

    def handle(request, response)
      case act(request.params.to_h)
        in Success[*records] then done(request, response, records)
        in Failure[:record, id, reason] then failed(response, id, reason)
        in Failure[:invalid, errors] then refuse(response, errors)
        else halt :internal_server_error
      end

      response.redirect_to(back(request))
    end

    private

    def details(request) = { tag: Blog::Types::Nullable::Tag[request.params[:tag]] }

    def done(request, response, records)
      toast(response, self.class::DONE.fetch(request.params[:act]), count: records.size, **details(request))
    end

    def failed(response, id, reason)
      code = self.class::REASONS.include?(reason) ? reason : :other

      toast(response, "#{self.class::FAILED}.#{code}", **named(id))
    end

    def refusal(_errors) = Blog::Contract::FORMAT

    def refuse(response, errors)
      code = refused(errors)
      key = "#{self.class::INVALID}.#{code}"

      toast(response, i18n.exists?(key) ? key : "#{REFUSALS}#{code}", max: Blog::Contract::MAX_IDS)
    end

    def refused(errors)
      case errors
        in { ids: [LONG, *] } then LONG
        in { ids: [::String, *] } then Blog::Contract::BLANK
        in { ids: } then Blog::Contract::FORMAT
        in { tag: [message, *] } then "tag_#{message}"
        else refusal(errors)
      end
    end
  end
end
