# frozen_string_literal: true

require "base64"

RSpec.describe "MCP share tools", type: :request do
  def answer(name, **) = JSON.parse(mcp_text(name, **))

  def file(text, filename, content_type = nil)
    { data: Base64.strict_encode64(text), filename:, content_type: }.compact
  end

  def group_link(id) = "http://shares.localhost/#{Shares::Slice['repos.share_group_queries'].find(id).code}"

  def make_group(*files) = Shares::Slice["operations.upload_share_group"].call(files).value!

  def refusal(name, **) = mcp_call(name, **).values_at("isError", "content")

  def share_link(id) = "http://shares.localhost/#{Shares::Slice['repos.share_queries'].find(id).code}"

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
      expect(group.fetch("url")).to eq(group_link(group.fetch("id")))
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

      expect(answer("list_shares", query: "notes").fetch("shares").map { it.fetch("filename") }).to eq(%w[notes.txt])
    end

    it "refuses the old search filter" do
      expect(mcp_call("list_shares", search: "notes").fetch("isError")).to be(true)
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

  describe "update_share" do
    let(:share) { upload_share.value! }

    it "renames a share" do
      expect(answer("update_share", id: share.id, filename: "b.txt")).to include("filename" => "b.txt")
    end

    it "sets a share's alt text and keeps its code", :aggregate_failures do
      answered = answer("update_share", id: share.id, alt_text: "A red door")

      expect(answered).to include("alt_text" => "A red door", "code" => share.code)
      expect(answer("update_share", id: share.id, alt_text: "")).to include("alt_text" => nil)
    end

    it "changes a share's code and moves its link", :aggregate_failures do
      answered = answer("update_share", id: share.id, code: " Resume-Me ")

      expect(answered).to include("code" => "resume-me", "url" => "http://shares.localhost/resume-me")
      expect(Shares::Slice["relations.short_codes"].pluck(:code)).to eq(["resume-me"])
    end

    it "refuses a code another share holds and keeps its own", :aggregate_failures do
      other = upload_share.value!

      expect(refusal("update_share", id: share.id, code: other.code).last.first.fetch("text"))
        .to include("another share or short link already has this code")
      expect(share_link(share.id)).to eq("http://shares.localhost/#{share.code}")
    end

    it "refuses a code that breaks the format" do
      expect(refusal("update_share", id: share.id, code: "re--sume").last.first.fetch("text"))
        .to include("code takes lowercase letters and digits")
    end

    it "refuses an ID no share holds" do
      expect(refusal("update_share", id: 0, alt_text: "A door").first).to be(true)
    end
  end

  describe "update_share_group" do
    it "names a group, and read_share_group reads the name back" do
      group = make_group(share_upload("a", "a.txt", "text/plain"))
      answer("update_share_group", id: group.id, name: "Beach trip")

      expect(answer("read_share_group", id: group.id)).to include("name" => "Beach trip")
    end
  end

  describe "update_share_group_file" do
    it "renames a file in a group" do
      group = make_group(share_upload("a", "a.txt", "text/plain"))
      file = group.share_group_files.first

      expect(answer("update_share_group_file", id: group.id, file_id: file.id, filename: "b.txt").fetch("files"))
        .to contain_exactly(include("id" => file.id, "filename" => "b.txt"))
    end

    it "refuses a blank name" do
      group = make_group(share_upload("a", "a.txt", "text/plain"))

      expect(refusal("update_share_group_file", id: group.id, file_id: group.share_group_files.first.id, filename: "")
        .first).to be(true)
    end
  end

  describe "delete_share" do
    let(:share) { upload_share.value! }

    it "deletes the share and its stored file", :aggregate_failures do
      removed = stub_request(:delete, share_store_url(share.key))

      expect(answer("delete_share", id: share.id)).to eq("id" => share.id, "deleted" => true)
      expect(shares).to be_empty
      expect(removed).to have_been_requested
    end

    it "keeps the share when the store fails", :aggregate_failures do
      stub_request(:delete, share_store_url(share.key)).to_return(status: 500)

      expect(refusal("delete_share", id: share.id))
        .to eq([true, [{ "type" => "text", "text" => API::Helpers::Upload::STORE_DOWN }]])
      expect(shares.size).to eq(1)
    end

    it "refuses an ID no share holds" do
      expect(refusal("delete_share", id: 0).first).to be(true)
    end
  end

  describe "delete_share_group" do
    let(:group) { make_group(share_upload("a", "a.txt", "text/plain"), share_upload("b", "b.txt", "text/plain")) }

    it "deletes the group and every stored file", :aggregate_failures do
      removed = group.share_group_files.map { stub_request(:delete, share_store_url(it.key)) }

      expect(answer("delete_share_group", id: group.id)).to eq("id" => group.id, "deleted" => true)
      expect(Shares::Slice["relations.share_groups"].to_a).to be_empty
      expect(removed).to all(have_been_requested)
    end

    it "refuses an ID no group holds" do
      expect(refusal("delete_share_group", id: 0).first).to be(true)
    end
  end

  describe "group_shares" do
    it "groups single shares under one new link" do
      ids = [upload_share.value!.id, upload_share.value!.id]

      expect(answer("group_shares", ids:).fetch("files").map { it.fetch("id") }).to match_array(ids)
    end

    it "refuses one share" do
      expect(refusal("group_shares", ids: [upload_share.value!.id]).first).to be(true)
    end
  end

  describe "add_shares_to_group" do
    it "moves a single share into a group" do
      group = make_group(share_upload("a", "a.txt", "text/plain"))
      share = upload_share.value!

      expect(answer("add_shares_to_group", id: group.id, ids: [share.id]).fetch("files").map { it.fetch("id") })
        .to include(share.id)
    end
  end

  describe "ungroup_share_file" do
    it "pulls a file out of its group under a new code" do
      group = make_group(share_upload("a", "a.txt", "text/plain"), share_upload("b", "b.txt", "text/plain"))
      file = group.share_group_files.first
      answered = answer("ungroup_share_file", id: group.id, file_id: file.id)

      expect(answered).to include("id" => file.id, "url" => share_link(file.id))
    end
  end

  describe "remove_share_group_file" do
    let(:group) { make_group(share_upload("a", "a.txt", "text/plain"), share_upload("b", "b.txt", "text/plain")) }
    let(:file) { group.share_group_files.first }
    let(:remaining) { Shares::Slice["repos.share_group_queries"].find(group.id)&.share_group_files&.map(&:id) }

    it "deletes one file and its stored file and keeps the rest of the group", :aggregate_failures do
      removed = stub_request(:delete, share_store_url(file.key))

      expect(answer("remove_share_group_file", id: group.id, file_id: file.id))
        .to eq("id" => group.id, "file_id" => file.id, "deleted" => true)
      expect(remaining).to eq([group.share_group_files.last.id])
      expect(removed).to have_been_requested
    end

    it "deletes the group with its last file" do
      lone = make_group(share_upload("a", "a.txt", "text/plain"))
      stub_request(:delete, share_store_url(lone.share_group_files.first.key))
      answer("remove_share_group_file", id: lone.id, file_id: lone.share_group_files.first.id)

      expect(Shares::Slice["repos.share_group_queries"].find(lone.id)).to be_nil
    end

    it "keeps the file when the store fails", :aggregate_failures do
      stub_request(:delete, share_store_url(file.key)).to_return(status: 500)

      expect(refusal("remove_share_group_file", id: group.id, file_id: file.id))
        .to eq([true, [{ "type" => "text", "text" => API::Helpers::Upload::STORE_DOWN }]])
      expect(remaining.size).to eq(2)
    end

    it "refuses a file the group does not hold" do
      expect(refusal("remove_share_group_file", id: group.id, file_id: 0).first).to be(true)
    end

    it "refuses an ID no group holds" do
      expect(refusal("remove_share_group_file", id: 0, file_id: 1).first).to be(true)
    end
  end
end
