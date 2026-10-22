# frozen_string_literal: true

module Admin
  module Helpers
    module ContactText
      PARTIAL = /\A(\d{4}|-)-(\d{2})-(\d{2})\z/

      module_function

      def address_lines(address)
        place = [address["city"], address["region"]].compact.join(", ")
        place = [place, address["postal_code"]].reject(&:empty?).join(" ") if address["postal_code"]

        [address["street"], address["extended"], place, address["country"]].compact.reject(&:empty?)
      end

      def age(birthday, today)
        year = birthday[/\A\d{4}/]&.to_i
        return unless year

        today.year - year - (today.strftime("%m-%d") < birthday[5..] ? 1 : 0)
      end

      def day(value)
        year, month, date = value.to_s.match(PARTIAL)&.captures
        return value.to_s unless year

        [Date::ABBR_MONTHNAMES[month.to_i], date.to_i].join(" ") + (year == "-" ? "" : ", #{year}")
      end
    end
  end
end
