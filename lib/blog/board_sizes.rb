# frozen_string_literal: true

module Blog
  BoardSizes = Data.define(:sizes, :step) do
    def self.from(params, step)
      sizes = Types::TaskColumn.values.to_h { [it, [step, Types::BoardSizeParam[params[it.to_sym]].to_i].max] }
      new(sizes:, step:)
    end

    def grown = sizes.reject { |_, size| size == step }.transform_keys(&:to_sym)

    def left(count, shown) = count - shown

    def more(column) = grown.merge(column.to_sym => sizes.fetch(column) + step)
  end
end
