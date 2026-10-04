# frozen_string_literal: true

RSpec.describe Links::Queries::FindRecords do
  let(:kinds) { Blog::Types::RecordKind.values }

  def find(...) = Links::Slice["queries.find_records"].call(...)

  it "finds a record of every kind by its title" do
    records = kinds.to_h { [it, linkable_record(it, "Zeppelin #{it}")] }

    expect(find("zeppelin").transform_values { it.map(&:id) }).to eq(records.transform_values { [it.id] })
  end

  describe "finding by text beyond the title" do
    it "finds a task by its note" do
      task = create(:task, note: "Bring the zeppelin")

      expect(find("zeppelin")["task"].map(&:id)).to eq([task.id])
    end

    it "finds a post by its body" do
      post = create(:post, body: "All about the zeppelin")

      expect(find("zeppelin")["post"].map(&:id)).to eq([post.id])
    end

    it "finds a social post by a later part" do
      social_post = create(:social_post, :thread)
      create(:social_post_part, social_post_id: social_post.id, body: "And a zeppelin")

      expect(find("zeppelin")["social_post"].map(&:id)).to eq([social_post.id])
    end

    it "finds a journal entry past its first line" do
      entry = create(:journal_entry, body: "Morning\nSaw a zeppelin")

      expect(find("zeppelin")["journal_entry"].map(&:id)).to eq([entry.id])
    end

    it "finds a commit by its repo" do
      commit = create(:commit, repo: "aaronmallen/zeppelin")

      expect(find("zeppelin")["commit"].map(&:id)).to eq([commit.id])
    end

    it "finds a project by its tagline" do
      project = create(:project, tagline: "Tracks a zeppelin")

      expect(find("zeppelin")["project"].map(&:id)).to eq([project.id])
    end

    it "finds a work entry by its blurb" do
      entry = create(:work_entry, blurb: "Flew a zeppelin")

      expect(find("zeppelin")["work_entry"].map(&:id)).to eq([entry.id])
    end

    it "finds a decision by its problem" do
      decision = create(:decision, problem: "Which zeppelin to buy")

      expect(find("zeppelin")["decision"].map(&:id)).to eq([decision.id])
    end
  end

  it "keeps a few of each kind, newest first" do
    today = Blog::TimeZone.today
    newer, newest = [3, 2, 1].map { create(:journal_entry, body: "zeppelin", entry_date: today - it) }.drop(1)

    expect(find("zeppelin", limit: 2)["journal_entry"].map(&:id)).to eq([newest.id, newer.id])
  end

  it "treats the text as plain, not as a pattern" do
    create(:task, title: "Half done")

    expect(find("%")).to eq({})
  end

  it "finds nothing for blank text" do
    create(:task, title: "Anything")

    expect(find("   ")).to eq({})
  end

  it "leaves out the kinds that match nothing" do
    create(:decision, title: "Zeppelin")

    expect(find("zeppelin").keys).to eq(["decision"])
  end
end
