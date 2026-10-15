# frozen_string_literal: true

RSpec.describe Posts::Jobs::RerenderPosts do
  let(:post_queries) { Posts::Slice["repos.post_queries"] }

  def rerender = described_class.new.perform

  def stale(relation, id, **) = Posts::Slice["relations.#{relation}"].by_pk(id).update(**)

  it "never retries, since tomorrow's run renders every post again" do
    expect(described_class.get_sidekiq_options["retry"]).to be(false)
  end

  it "rebuilds every stored value from the post's markdown" do
    post = create(:post, body: "## Setup\n\none *two* three")
    stale(:posts, post.id, body_html: "<p>old</p>", first_paragraph: "old", read_time: 9, word_count: 1)
    rerender

    rendered = { first_paragraph: "one two three", read_time: 1, word_count: 4 }
    expect(post_queries.by_id(post.id)).to have_attributes(body_html: include("<em>two</em>"), **rendered)
  end

  it "rebuilds an edit note's html" do
    edit = create(:post_edit, note: "Fixed *it*")
    stale(:post_edits, edit.id, note_html: "<p>old</p>")
    rerender

    expect(post_queries.edits_for_post(edit.post_id).map(&:note_html)).to eq(["<p>Fixed <em>it</em></p>\n"])
  end

  it "leaves updated_at alone, since the post did not change" do
    post = create(:post, updated_at: Time.now - 3600)
    stale(:posts, post.id, body_html: "<p>old</p>")

    expect { rerender }.not_to(change { post_queries.by_id(post.id).updated_at })
  end

  it "writes only the rows whose stored values went stale" do
    create(:post)
    stale(:posts, create(:post).id, word_count: 0)

    expect(rerender).to eq(1)
  end
end
