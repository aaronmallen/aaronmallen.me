# frozen_string_literal: true

RSpec.describe "Splitting tags into a public and a private scope", type: :migration do
  let(:gateway) { Tags::Slice["db.rom"].gateways[:default] }
  let(:db) { gateway.connection }
  let(:owners) do
    { post: create(:post), project: create(:project), journal_entry: create(:journal_entry), task: create(:task) }
  end
  let(:joins) do
    {
      post: %i[post_tags post_id],
      project: %i[project_tags project_id],
      journal_entry: %i[journal_entry_tags journal_entry_id],
      task: %i[task_tags task_id],
    }
  end

  def held(kind, columns = %i[name color scope])
    table, key = joins.fetch(kind)

    db[table].join(:tags, id: :tag_id).where(key => owners.fetch(kind).id).select_map(columns)
  end

  def join(kind, tag_id, **)
    table, key = joins.fetch(kind)

    db[table].insert(key => owners.fetch(kind).id, tag_id:, **)
  end

  def migrate(target = nil)
    path = Hanami.app.root.join("config/db/migrate").to_s

    ROM::SQL.with_gateway(gateway) { Sequel::Migrator.run(db, path, **{ target: }.compact) }
  end

  def rows(name) = db[:tags].where(name:).order(:scope).select_map(%i[scope color])

  def tag(name, color = "mk-blue", **) = db[:tags].insert(name:, color:, **)

  before do
    owners
    migrate(20_260_928_000_046)
  end

  describe "a tag on every kind" do
    before do
      id = tag("hanakai", "mk-violet")
      owners.each_key { join(it, id) }
      migrate
    end

    it "becomes a public row and a private row in the same color" do
      expect(rows("hanakai")).to eq([%w[public mk-violet], %w[private mk-violet]])
    end

    it "keeps each kind joined to the row for its side" do
      expect(owners.keys.flat_map { held(it) })
        .to eq(%w[public public private private].map { ["hanakai", "mk-violet", it] })
    end

    it "merges the two rows back on the way down", :aggregate_failures do
      migrate(20_260_928_000_046)

      expect(db[:tags].where(name: "hanakai").select_map(:color)).to eq(%w[mk-violet])
      expect(owners.keys.map { held(it, :name) }).to all(eq(%w[hanakai]))
    end
  end

  { post: "public", project: "public", journal_entry: "private", task: "private" }.each do |kind, scope|
    it "gives a tag only a #{kind.to_s.tr('_', ' ')} carries the #{scope} scope", :aggregate_failures do
      id = tag("ruby", "mk-sand")
      join(kind, id)
      migrate

      expect(db[:tags].where(name: "ruby").select_map(%i[id scope color])).to eq([[id, scope, "mk-sand"]])
      expect(held(kind)).to eq([["ruby", "mk-sand", scope]])
    end
  end

  it "makes a tag nothing carries public" do
    tag("unused")
    migrate

    expect(rows("unused")).to eq([%w[public mk-blue]])
  end

  describe "after the split" do
    before { migrate }

    it "holds a name once in each scope" do
      tag("ruby", scope: "public")
      tag("ruby", scope: "private")

      expect { tag("ruby", scope: "public") }.to raise_error(Sequel::UniqueConstraintViolation, /tags_scope_name_key/)
    end

    { post: "private", project: "private", journal_entry: "public", task: "public" }.each do |kind, other|
      it "refuses a #{kind.to_s.tr('_', ' ')} tag that points at a #{other} tag" do
        expect { join(kind, tag("ruby", scope: other)) }.to raise_error(Sequel::ForeignKeyConstraintViolation)
      end

      it "refuses a #{kind.to_s.tr('_', ' ')} tag that claims the #{other} scope" do
        expect { join(kind, tag("ruby", scope: other), tag_scope: other) }
          .to raise_error(Sequel::CheckConstraintViolation)
      end
    end
  end
end
