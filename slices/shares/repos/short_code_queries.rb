# frozen_string_literal: true

module Shares
  module Repos
    class ShortCodeQueries < Blog::DB::Repo
      OWNED = %i[share_group_files share_groups short_links].freeze
      OWNERS = [
        Sequel[:share_group_files][:id].as(:share_id), Sequel[:share_groups][:id].as(:share_group_id),
        Sequel[:short_links][:destination],
      ].freeze

      def free_code(length = Helpers::Code::MIN_LENGTH)
        alphabet = Helpers::Code::ALPHABET
        codes = short_codes.where(Sequel.char_length(:code) => length).where(code: /^[#{alphabet.join}]+$/)
        return free_code(length + 1) if codes.count >= alphabet.size**length

        Helpers::Code.pick(length, codes.pluck(:code))
      end

      def owner(code)
        id = Sequel[:short_codes][:id]
        found = short_codes.dataset.unordered.where(Sequel[:short_codes][:code] => code)
        found = OWNED.reduce(found) { |owned, table| owned.left_join(table, short_code_id: id) }
        found.select(*OWNERS).first
      end
    end
  end
end
