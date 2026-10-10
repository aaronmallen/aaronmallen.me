# auto_register: false
# frozen_string_literal: true

module Admin
  class BulkAction < Action
    KEY = "#"
    LONG = "long"

    def handle(request, response)
      case operation.call(request.params.to_h)
        in Success[*records] then done(request, response, records.size)
        in Failure[:record, id, reason] then failed(response, id, reason)
        in Failure[:invalid, errors] then toast(response, "#{self.class::INVALID}.#{refused(errors)}")
        else halt 500
      end

      response.redirect_to(back(request))
    end

    private

    def details(_request) = {}

    def done(request, response, count)
      toast(response, self.class::DONE.fetch(request.params[:act]), count:, **details(request))
    end

    def failed(response, id, reason)
      code = self.class::REASONS.include?(reason) ? reason : :other

      toast(response, "#{self.class::FAILED}.#{code}", **named(id))
    end

    def landing(request)
      number = Blog::Types::PageParam.call(request.params[:page]) { 1 }
      return number if number == 1

      page = Blog::Structs::Page.new(number:, size: page_size)
      yield(page) ? number - 1 : number
    end

    def refusal(_errors) = Blog::Contract::FORMAT

    def refused(errors)
      case errors
        in { ids: [LONG, *] } then LONG
        in { ids: [::String, *] } then Blog::Contract::BLANK
        in { ids: } then Blog::Contract::FORMAT
        else refusal(errors)
      end
    end
  end
end
