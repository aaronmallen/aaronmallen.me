# frozen_string_literal: true

RSpec.describe Activity::Queries::StalledList do
  let(:today) { Blog::TimeZone.today }

  def days_ago(days) = Time.now - (days * 24 * 60 * 60)

  def rows = Activity::Slice["queries.stalled_list"].call

  def rows_of(kind) = rows.select { it.kind == kind }

  it "returns no rows when nothing is stale" do
    create(:task, carried_count: 1)
    create(:task, :someday)
    create(:post, :draft)
    create(:journal_entry, entry_date: today)

    expect(rows).to be_empty
  end

  describe "a carried task" do
    it "comes back with its count once carried three days" do
      task = create(:task, carried_count: 3)

      expect(rows_of("carried").map { [it.record_id, it.days] }).to eq([[task.id, 3]])
    end

    it "stays out when carried twice" do
      create(:task, :carried)

      expect(rows_of("carried")).to be_empty
    end

    it "stays out once done" do
      create(:task, :done, carried_count: 5)

      expect(rows_of("carried")).to be_empty
    end

    it "carries its title" do
      create(:task, carried_count: 3, title: "Write the card")

      expect(rows_of("carried").map(&:title)).to eq(["Write the card"])
    end
  end

  describe "a draft" do
    it "comes back once untouched for thirty days" do
      post = create(:post, :draft, updated_at: days_ago(30))

      expect(rows_of("draft").map { [it.record_id, it.days] }).to eq([[post.id, 30]])
    end

    it "stays out when edited yesterday" do
      create(:post, :draft, updated_at: days_ago(1))

      expect(rows_of("draft")).to be_empty
    end

    it "stays out once published" do
      create(:post, :published, updated_at: days_ago(60))

      expect(rows_of("draft")).to be_empty
    end
  end

  describe "a someday task" do
    it "comes back once untouched for ninety days" do
      task = create(:task, :someday, updated_at: days_ago(90))

      expect(rows_of("someday").map { [it.record_id, it.days] }).to eq([[task.id, 90]])
    end

    it "stays out when closed" do
      create(:task, :someday, :done, updated_at: days_ago(120))

      expect(rows_of("someday")).to be_empty
    end

    it "stays out when on the next list" do
      create(:task, updated_at: days_ago(120))

      expect(rows_of("someday")).to be_empty
    end
  end

  describe "the journal" do
    it "comes back after two days without an entry, with the day count" do
      create(:journal_entry, entry_date: today - 5)
      create(:journal_entry, entry_date: today - 2)

      expect(rows_of("journal").map { [it.record_id, it.days] }).to eq([[nil, 2]])
    end

    it "stays out with an entry yesterday" do
      create(:journal_entry, entry_date: today - 1)

      expect(rows_of("journal")).to be_empty
    end

    it "stays out with no entries at all" do
      expect(rows_of("journal")).to be_empty
    end
  end

  describe "the limits in settings" do
    it "brings a draft in when its limit drops" do
      create(:post, :draft, updated_at: days_ago(10))
      change_attention_limit(:draft_days, to: 10)

      expect(rows_of("draft").length).to eq(1)
    end

    it "leaves a carried task out when its limit rises" do
      create(:task, carried_count: 3)
      change_attention_limit(:carried_count, to: 4)

      expect(rows_of("carried")).to be_empty
    end

    it "brings the journal row in when its limit drops" do
      create(:journal_entry, entry_date: today - 1)
      change_attention_limit(:journal_days, to: 1)

      expect(rows_of("journal").map(&:days)).to eq([1])
    end
  end

  it "puts the row furthest past its limit, as a share of that limit, first" do
    create(:task, carried_count: 4)
    create(:post, :draft, updated_at: days_ago(60))
    create(:task, :someday, updated_at: days_ago(100))
    create(:journal_entry, entry_date: today - 3)

    expect(rows.map(&:kind)).to eq(%w[draft journal carried someday])
  end
end
