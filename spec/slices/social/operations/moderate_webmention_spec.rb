# frozen_string_literal: true

RSpec.describe Social::Operations::ModerateWebmention do
  def moderate(id, verdict) = Social::Slice["operations.moderate_webmention"].call(id, verdict)

  def status(mention) = Social::Slice["relations.webmentions"].by_pk(mention.id).one[:status]

  {
    "a pending mention" => [],
    "an approved mention" => [:approved],
    "a spam mention" => [:spam],
    "an ignored mention" => [:ignored],
  }.to_a.product(%w[approved spam ignored]).each do |(what, traits), verdict|
    it "stores #{what} as #{verdict}" do
      mention = create(:webmention, *traits)
      moderate(mention.id, verdict)

      expect(status(mention)).to eq(verdict)
    end
  end

  it "answers with the moderated mention" do
    mention = create(:webmention)

    expect(moderate(mention.id, "ignored").value!).to have_attributes(id: mention.id, status: "ignored")
  end

  it "fails as not found for a mention that is gone" do
    expect(moderate(create(:webmention).id + 1, "ignored").failure).to eq(:not_found)
  end
end
