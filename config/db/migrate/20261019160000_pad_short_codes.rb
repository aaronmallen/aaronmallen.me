# frozen_string_literal: true

require "securerandom"

ROM::SQL.migration do
  up do
    alphabet = "abcdefghjkmnpqrstuvwxyz23456789".chars
    rows = from(:short_codes).order(:id).select_map(%i[id code])
    taken = rows.to_set(&:last)
    pad = ->(code) { code + Array.new(8 - code.length) { alphabet.sample(random: SecureRandom) }.join }
    padded = rows.map do |id, code|
      next [id, code, code] if code.length >= 8

      new_code = pad.call(code)
      new_code = pad.call(code) while taken.include?(new_code)
      taken << new_code
      [id, code, new_code]
    end

    lost = padded.filter_map do |id, code, _|
      owner = padded.find { it[2] == code } || padded.find { it[2].start_with?(code) }
      code unless owner.first == id
    end
    raise "padding would stop these short codes opening their own records: #{lost.join(', ')}" unless lost.empty?

    padded.each do |id, code, new_code|
      from(:short_codes).where(id:).update(code: new_code) unless code == new_code
    end

    run "ALTER DOMAIN short_code ADD CONSTRAINT short_code_length CHECK (char_length(VALUE) >= 8)"
  end

  down do
    run "ALTER DOMAIN short_code DROP CONSTRAINT short_code_length"
  end
end
