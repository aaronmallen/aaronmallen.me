# frozen_string_literal: true

module Blog
  class BulkContract < Contract
    params do
      required(:ids).value(Types::IdList, :filled?, max_size?: MAX_IDS)
    end

    register_macro(:tag_for) do |macro:|
      next unless macro.args.flatten.include?(values[:act])

      key(:tag).failure(BLANK) if values[:tag].nil?
      key(:tag).failure(FORMAT) unless values[:tag].nil? || Types::Tag.valid?(values[:tag])
    end
  end
end
