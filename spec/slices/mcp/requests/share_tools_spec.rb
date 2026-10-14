# frozen_string_literal: true

require "base64"

RSpec.describe "MCP share tools", type: :request do
  def answer(name, **) = JSON.parse(mcp_text(name, **))

  def file(text, filename, content_type = nil)
    { data: Base64.strict_encode64(text), filename:, content_type: }.compact
  end

  def make_group(*files) = Shares::Slice["operations.upload_share_group"].call(files).value!

  def refusal(name, **) = mcp_call(name, **).values_at("isError", "content")

  def shares = Shares::Slice["relations.shares"].to_a

  before do
    connect_share_store
    stub_request(:put, %r{\A#{share_store_url}/}).to_return(status: 200)
  end

  describe "upload_share" do
    it "shares the file and answers its link" do
      answered = answer("upload_share", **file("hello", "hello.txt", "text/plain"))

      expect(answered).to include(
        "id" => shares.first[:id], "url" => "http://shares.localhost/#{answered.fetch('code')}",
        "filename" => "hello.txt", "content_type" => "text/plain", "byte_size" => 5,
      )
    end

    it "refuses data that is not base64 and shares nothing", :aggregate_failures do
      expect(refusal("upload_share", data: "not*base64!", filename: "a.txt").first).to be(true)
      expect(shares).to be_empty
    end

    it "refuses when the store does not answer" do
      stub_request(:put, %r{\A#{share_store_url}/}).to_timeout

      expect(refusal("upload_share", **file("a", "a.txt")))
        .to eq([true, [{ "type" => "text", "text" => API::Helpers::Upload::STORE_DOWN }]])
    end
  end

  describe "upload_share_group" do
    let(:group) { answer("upload_share_group", files: [file("a", "a.txt", "text/plain"), file("bb", "b.txt")]) }

    it "shares the files under one link" do
      expect(group.fetch("url")).to eq("http://shares.localhost/#{group.fetch('code')}")
    end

    it "answers each file with its own link under the group's" do
      link = group.fetch("url")
      first, second = group.fetch("files").map { it.fetch("id") }

      expect(group.fetch("files").map { it.values_at("filename", "url") })
        .to eq([["a.txt", "#{link}/#{first}"], ["b.txt", "#{link}/#{second}"]])
    end

    it "refuses a group with no files" do
      expect(refusal("upload_share_group", files: []).first).to be(true)
    end
  end

  describe "list_shares" do
    it "lists the shares newest first with their count" do
      upload_share("one", "one.txt")
      upload_share("two", "two.txt")

      listed = answer("list_shares")

      expect([listed.fetch("count"), listed.fetch("shares").map { it.fetch("filename") }])
        .to eq([2, %w[two.txt one.txt]])
    end

    it "finds a share by the words in its name" do
      upload_share("one", "notes.txt")
      upload_share("two", "other.txt")

      expect(answer("list_shares", search: "notes").fetch("shares").map { it.fetch("filename") }).to eq(%w[notes.txt])
    end
  end

  describe "read_share" do
    it "reads one share by ID" do
      share = upload_share.value!

      expect(answer("read_share", id: share.id)).to include("id" => share.id, "code" => share.code)
    end

    it "refuses an ID no share holds" do
      expect(refusal("read_share", id: 0).first).to be(true)
    end
  end

  describe "list_share_groups" do
    it "lists the groups with their files" do
      make_group(share_upload("a", "a.txt", "text/plain"))

      listed = answer("list_share_groups")

      expect([listed.fetch("count"), listed.fetch("share_groups").first.fetch("files").size]).to eq([1, 1])
    end
  end

  describe "read_share_group" do
    it "reads one group by ID with its files" do
      group = make_group(share_upload("a", "a.txt", "text/plain"), share_upload("b", "b.png", "image/png"))

      expect(answer("read_share_group", id: group.id).fetch("files").map { it.fetch("filename") })
        .to eq(%w[a.txt b.png])
    end

    it "refuses an ID no group holds" do
      expect(refusal("read_share_group", id: 0).first).to be(true)
    end
  end
end
