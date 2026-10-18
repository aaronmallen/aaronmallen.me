# frozen_string_literal: true

ROM::SQL.migration do
  up do
    loose = from(:tasks).where(project_id: nil)
    loose.update(number: Sequel[:number] + loose.max(:number).to_i)

    ranked = loose.select(:id, Sequel.function(:row_number).over(order: :number).as(:rank))
    from(:tasks, ranked.as(:ranked))
      .where(Sequel[:tasks][:id] => Sequel[:ranked][:id])
      .update(number: Sequel[:ranked][:rank])

    from(:task_number_counters).where(project_id: nil).delete
    last = loose.max(:number)
    from(:task_number_counters).insert(project_id: nil, last_number: last) if last
  end
end
