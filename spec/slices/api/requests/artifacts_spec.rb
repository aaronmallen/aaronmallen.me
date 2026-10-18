# frozen_string_literal: true

RSpec.describe "API artifacts", type: :request do
  let(:artifact) { call_api(:post, "/artifacts", { title: "Plan", type: "plan", body: "## Steps" }).fetch("id") }

  it "names the owner when a write names no agent" do
    expect(call_api(:get, "/artifacts/#{artifact}").fetch("versions"))
      .to match([include("number" => 1, "agent" => nil, "model" => nil)])
  end

  it "keeps the tags it is given, lowercased" do
    call_api(:patch, "/artifacts/#{artifact}", { tags: %w[Site perf] })

    expect(document.fetch("tags")).to eq(%w[site perf])
  end

  it "refuses a tag that is not a slug" do
    call_api(:patch, "/artifacts/#{artifact}", { tags: ["two words"] })

    expect([last_response.status, document.fetch("errors")])
      .to eq([422, { "tags" => ["a tag is lowercase words joined by hyphens"] }])
  end

  it "refuses a type it does not know" do
    call_api(:post, "/artifacts", { title: "Plan", type: "memo", body: "## Steps" })

    expect(last_response.status).to eq(422)
  end

  it "answers a version past the latest with a 404" do
    call_api(:get, "/artifacts/#{artifact}?version=2")

    expect([last_response.status, document.fetch("message")]).to eq([404, "artifact #{artifact} has no version 2"])
  end

  it "deletes an artifact for a token with agents and delete" do
    call_api(:delete, "/artifacts/#{artifact}", nil, token: api_token(%w[agents delete]))

    expect(document).to eq("id" => artifact, "deleted" => true)
  end

  it "refuses to delete an artifact for a token with agents alone" do
    call_api(:delete, "/artifacts/#{artifact}", nil, token: api_token(%w[agents]))

    expect([last_response.status, document.fetch("error_description")])
      .to eq([403, "this endpoint needs a token with the delete scope"])
  end

  it "refuses artifacts to a token without agents" do
    call_api(:get, "/artifacts", nil, token: api_token(%w[read write delete]))

    expect(last_response.status).to eq(403)
  end
end
