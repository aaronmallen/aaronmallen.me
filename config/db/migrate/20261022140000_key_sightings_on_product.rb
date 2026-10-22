# frozen_string_literal: true

ROM::SQL.migration do
  old_key = %i[api_token_id oauth_client_id browser os city country]
  new_key = %i[api_token_id oauth_client_id browser os product]

  merge = Kernel.lambda do |db, key|
    newest = [Sequel.desc(:last_seen_at), Sequel.desc(:id)]
    ranked = db[:sightings].select(
      :id,
      Sequel.function(:first_value, :id).over(partition: key, order: newest).as(:keep),
      Sequel.function(:sum, :calls).over(partition: key).as(:calls),
      Sequel.function(:min, :first_seen_at).over(partition: key).as(:first_seen_at),
    )
    merged = db.from(:sightings, ranked.as(:ranked)).where(Sequel[:sightings][:id] => Sequel[:ranked][:id])

    merged.where(Sequel[:ranked][:id] => Sequel[:ranked][:keep])
          .update(calls: Sequel[:ranked][:calls], first_seen_at: Sequel[:ranked][:first_seen_at])
    merged.exclude(Sequel[:ranked][:id] => Sequel[:ranked][:keep]).delete
  end

  up do
    alter_table(:sightings) { add_column :product, :text }
    self[:sightings].update(product: Sequel.function(:substring, :last_user_agent, "^\\s*([^\\s/()]+)"))
    merge.call(self, new_key)

    alter_table :sightings do
      drop_index old_key, name: :sightings_credential_device_place_index
      add_index new_key, unique: true, nulls_distinct: false, name: :sightings_credential_device_product_index
    end
  end

  down do
    merge.call(self, old_key)

    alter_table :sightings do
      drop_index new_key, name: :sightings_credential_device_product_index
      add_index old_key, unique: true, nulls_distinct: false, name: :sightings_credential_device_place_index
      drop_column :product
    end
  end
end
