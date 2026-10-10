# frozen_string_literal: true

module Activity
  module Structs
    DeadJob = Data.define(:jid, :name, :args, :died_at, :error) do
      def self.from(entry)
        new(
          jid: entry.jid,
          name: entry.display_class,
          args: entry.args,
          died_at: entry.at,
          error: entry.item.values_at("error_class", "error_message").compact.join(": "),
        )
      end
    end
  end
end
