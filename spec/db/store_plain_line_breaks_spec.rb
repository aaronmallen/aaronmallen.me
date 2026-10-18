# frozen_string_literal: true

RSpec.describe "Storing plain line breaks", type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }
  let(:migration) do
    path = Hanami.app.root.join("config/db/migrate/20261018090001_store_plain_line_breaks.rb")
    ROM::SQL.with_gateway(Hanami.app["db.rom"].gateways[:default]) { load path.to_s }
    Sequel::Migration.descendants.last
  end

  let!(:article) { create(:post, :draft, body: "one\r\ntwo\rthree") }
  let!(:social_post) do
    Social::Slice["repos.social_post_mutations"]
      .create_with_parts(parts: ["four\r\nfive"], posted_at: nil, status: "draft", targets: %w[mastodon])
  end
  let!(:suggestion) do
    Suggestions::Slice["repos.suggestion_mutations"]
      .replace_for_post(article.id, [{ original: "one\r\ntwo", replacement: "one\r\n2", reason: "typo" }])
  end

  before { migration.apply(db, :up) }

  it "turns the line breaks in post bodies plain" do
    expect(db[:posts].where(id: article.id).get(:body)).to eq("one\ntwo\nthree")
  end

  it "turns the line breaks in social parts plain" do
    expect(db[:social_post_parts].where(social_post_id: social_post.id).get(:body)).to eq("four\nfive")
  end

  it "turns the line breaks in suggested edits plain" do
    edit = db[:suggestion_edits].where(suggestion_id: suggestion.id)

    expect(edit.get(%i[original replacement])).to eq(%W[one\ntwo one\n2])
  end
end
