# frozen_string_literal: true

RSpec.describe Links::Relations::RecordLinks do
  let(:db) { Links::Slice["db.rom"].gateways[:default].connection }
  let(:kinds) { Blog::Types::RecordKind.values }

  def link(kind, id, other_kind, other_id)
    Links::Slice["operations.link_records"].call(kind, id, { other_kind:, other_id: }).value!
  end

  def links_naming(kind, id)
    db[:record_links].where(Sequel.|({ left_kind: kind, left_id: id }, { right_kind: kind, right_id: id })).count
  end

  it "holds the kinds in the order the Ruby twin lists them" do
    order = db.from(:pg_enum).join(:pg_type, oid: :enumtypid).where(typname: "record_kind").order(:enumsortorder)

    expect(order.select_map(:enumlabel)).to eq(kinds)
  end

  describe "deleting a record" do
    let(:decision) { linkable_record("decision") }
    let(:tables) do
      {
        "task" => :tasks, "post" => :posts, "social_post" => :social_posts, "journal_entry" => :journal_entries,
        "commit" => :commits, "project" => :projects, "work_entry" => :work_entries, "decision" => :decisions,
        "pull_request" => :pull_requests,
      }
    end

    def linked_record(kind)
      linkable_record(kind).tap do |record|
        link(kind, record.id, "decision", decision.id) unless kind == "decision"
        link(kind, record.id, "post", linkable_record("post").id) unless kind == "post"
      end
    end

    it "removes the links of a record of any kind" do
      records = kinds.to_h { [it, linked_record(it)] }

      expect { records.each { |kind, record| db[tables.fetch(kind)].where(id: record.id).delete } }
        .to change { db[:record_links].count }.to(0)
    end

    it "keeps the links of other records" do
      task = linkable_record("task")
      link("task", task.id, "decision", decision.id)
      link("post", linkable_record("post").id, "decision", decision.id)

      db[:tasks].where(id: task.id).delete

      expect(links_naming("decision", decision.id)).to eq(1)
    end
  end

  it "refuses a row that names a missing record, whoever writes it" do
    decision = linkable_record("decision")
    row = { left_kind: "post", left_id: 999_999, right_kind: "decision", right_id: decision.id }

    expect { db[:record_links].insert(row) }.to raise_error(Sequel::ForeignKeyConstraintViolation, /record_links/)
  end
end
