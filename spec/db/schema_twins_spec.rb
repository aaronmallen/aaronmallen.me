# frozen_string_literal: true

RSpec.describe "Schema twins", type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }
  let(:renamed) do
    {
      "network" => Blog::Types::NetworkName.values,
      "task_event_kind" => Blog::Types::TaskTimelineKind.values - %w[comment session],
    }
  end
  let(:enums) do
    db.from(:pg_enum).join(:pg_type, oid: :enumtypid).join(:pg_namespace, oid: :typnamespace)
      .where(nspname: "public").order(:typname, :enumsortorder).select_map(%i[typname enumlabel])
      .group_by(&:first).transform_values { it.map(&:last) }
  end
  let(:triggers) do
    db.from(:pg_trigger).exclude(:tgisinternal).select_map(Sequel.function(:pg_get_triggerdef, :oid))
  end

  def drop_links(kind, table)
    /AFTER DELETE ON (public\.)?#{table} .*EXECUTE FUNCTION (public\.)?record_links_drop_record\('#{kind}'\)/
  end

  def inflector = Hanami.app.inflector

  def twin(name) = renamed.fetch(name) { Blog::Types.const_get(inflector.camelize(name)).values }

  it "names only enums the schema holds in the renamed list" do
    expect(enums.keys).to include(*renamed.keys)
  end

  it "keeps every enum's values in its Blog::Types twin" do
    enums.each do |name, values|
      expect(twin(name)).to match_array(values), "#{name} differs from its Blog::Types twin"
    end
  end

  it "drops the links of a deleted record of every kind" do
    enums.fetch("record_kind").each do |kind|
      table = inflector.pluralize(kind)
      expect(triggers).to include(drop_links(kind, table)), "#{table} has no trigger dropping its #{kind} links"
    end
  end
end
