# frozen_string_literal: true

RSpec.describe Blog::DB::Repo do
  let(:repo) { Tags::Slice["repos.tag_mutations"] }
  let(:tags) { Tags::Slice["relations.tags"] }
  let(:long_ago) { Time.utc(2020, 1, 1) }

  it "stamps both columns on create" do
    tag = repo.create(name: "ruby", color: "mk-pink", scope: "public")

    expect(tag).to have_attributes(created_at: be_within(5).of(Time.now), updated_at: tag.created_at)
  end

  it "stamps only updated_at on update" do
    tag = create(:tag)
    tags.by_pk(tag.id).update(created_at: long_ago, updated_at: long_ago)

    expect(repo.update(tag.id, name: "renamed"))
      .to have_attributes(created_at: long_ago, updated_at: be_within(5).of(Time.now))
  end
end
