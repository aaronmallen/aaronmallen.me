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
        "pull_request" => :pull_requests, "mail_thread" => :mail_threads,
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

  describe "the relation" do
    let(:decision) { linkable_record("decision") }

    def source(task_id) = Tasks::Slice["relations.record_links"].source_from_decision(task_id, decision.id)

    it "makes a link by hand related" do
      link("task", linkable_record("task").id, "decision", decision.id)

      expect(db[:record_links].select_map(:relation)).to eq(["related"])
    end

    it "keeps a hand link beside the sourced task of the same decision" do
      source(linkable_record("task").id)
      link("task", linkable_record("task").id, "decision", decision.id)

      expect(db[:record_links].order(:id).select_map(:relation)).to eq(%w[sourced_from related])
    end

    it "refuses a second task sourced from one decision" do
      source(linkable_record("task").id)

      expect { source(linkable_record("task").id) }
        .to raise_error(Sequel::UniqueConstraintViolation, /record_links_one_source_key/)
    end

    it "refuses a sourced link that isn't a task sourced from a decision" do
      row = { left_kind: "task", left_id: linkable_record("task").id, right_kind: "post",
              right_id: linkable_record("post").id, relation: "sourced_from" }

      expect { db[:record_links].insert(row) }
        .to raise_error(Sequel::CheckConstraintViolation, /record_links_sourced_from_check/)
    end
  end

  it "refuses a row that names a missing record, whoever writes it" do
    decision = linkable_record("decision")
    row = { left_kind: "post", left_id: 999_999, right_kind: "decision", right_id: decision.id }

    expect { db[:record_links].insert(row) }.to raise_error(Sequel::ForeignKeyConstraintViolation, /record_links/)
  end

  describe "a task and a project" do
    let(:task) { create(:task) }
    let(:project) { create(:project) }

    def project_id = db[:tasks].where(id: task.id).get(:project_id)

    def unlink(project_id) = Links::Slice["operations.unlink_records"].call("project", project_id, "task", task.id)

    it "keeps the pair on the task, not as a row" do
      link("project", project.id, "task", task.id)

      expect([project_id, links_naming("task", task.id)]).to eq([project.id, 0])
    end

    it "refuses a row that pairs them, whoever writes it" do
      row = { left_kind: "task", left_id: task.id, right_kind: "project", right_id: project.id }

      expect { db[:record_links].insert(row) }
        .to raise_error(Sequel::CheckConstraintViolation, /record_links_task_project_check/)
    end

    it "lists the pair from either side" do
      link("task", task.id, "project", project.id)
      queries = Links::Slice["repos.record_link_queries"]

      expect([queries.partners("task", task.id), queries.partners("project", project.id)])
        .to eq([[["project", project.id]], [["task", task.id]]])
    end

    it "refuses a project that is gone" do
      result = Links::Slice["operations.link_records"].call("task", task.id,
                                                            { other_kind: "project", other_id: 999_999 })

      expect(result).to eq(Dry::Monads::Failure([:invalid, { other_id: ["missing"] }]))
    end

    it "moves the task to the next project it links" do
      link("task", task.id, "project", project.id)
      link("task", task.id, "project", create(:project).id)

      expect(project_id).not_to eq(project.id)
    end

    it "clears the project on unlink, and refuses a project the task is not in", :aggregate_failures do
      link("task", task.id, "project", project.id)

      expect(unlink(create(:project).id)).to eq(Dry::Monads::Failure(:not_found))
      expect(unlink(project.id)).to be_success
      expect(project_id).to be_nil
    end

    it "clears the project when the project is deleted" do
      link("task", task.id, "project", project.id)

      db[:projects].where(id: project.id).delete

      expect(project_id).to be_nil
    end
  end
end
