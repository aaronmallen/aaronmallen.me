# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Calendar
      module Redirect
        TOASTS = "calendar_page.toasts"

        include Dry::Monads[:result]

        private

        def back(request)
          day = Blog::Types::DateParam[request.params[:day]]

          day ? { day: day.iso8601 } : Blog::Constants::EMPTY_HASH
        end

        def done(request, response, key, **)
          toast(response, "#{TOASTS}.#{key}", **)
          response.redirect_to(routes.path(:admin_calendar, **back(request)))
        end

        def move(request, response, operation, at:)
          case operation.call(record_id(request), request.params[:to])
            in Success(record) then done(request, response, :moved, **moved_to(record[at]))
            in Failure(:not_found) then halt 404
            in Failure(:invalid | :not_scheduled | :past => refusal) then done(request, response, refusal)
            else halt 500
          end
        end

        def moved_to(time)
          {
            date: i18n.l(Blog::TimeZone.today(time), format: :medium),
            time: i18n.l(Blog::TimeZone.local(time), format: :clock),
          }
        end

        def refused(request, response, errors)
          return done(request, response, :invalid_event) if errors.empty? || !block_given?

          yield errors
        end

        def written(request, response, result, key, &)
          case result
            in Success(calendar) then done(request, response, key, calendar: calendar.name)
            in Failure(:not_found) then halt 404
            in Failure(:read_only) then done(request, response, :read_only)
            in Failure[:invalid, errors] then refused(request, response, errors, &)
            in Failure[:google_failed, _] then done(request, response, :google_failed)
            else halt 500
          end
        end
      end
    end
  end
end
