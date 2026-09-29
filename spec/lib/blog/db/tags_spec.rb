# frozen_string_literal: true

RSpec.describe Blog::DB::Tags do
  let(:db) { Tags::Slice["db.rom"].gateways[:default].connection }

  def scopes(name) = db[:tags].where(name:).order(:scope).select_map(:scope)

  {
    post: "public",
    project: "public",
    journal_entry: "private",
    task: "private",
  }.each do |kind, scope|
    it "gives a #{kind.to_s.tr('_', ' ')} a #{scope} tag" do
      create(kind, tags: %w[ruby])

      expect(scopes("ruby")).to eq([scope])
    end
  end

  it "keeps a name on a post and a task as two rows, each on its own side", :aggregate_failures do
    post = create(:post, tags: %w[hanakai])
    task = create(:task, tags: %w[hanakai])

    expect(scopes("hanakai")).to eq(%w[public private])
    expect(post.tags.map(&:id)).not_to eq(task.tags.map(&:id))
  end

  it "reuses the tag its own scope holds" do
    first = create(:project, tags: %w[ruby])
    second = create(:post, tags: %w[ruby])

    expect(second.tags.map(&:id)).to eq(first.tags.map(&:id))
  end

  it "gives a new tag the color its own scope uses least" do
    (Blog::Types::TagColor.values - %w[mk-orange]).each { create(:tag, :private, color: it) }
    2.times { create(:tag, color: "mk-orange") }

    expect(create(:task, tags: %w[fresh]).tags.first.color).to eq("mk-orange")
  end
end
