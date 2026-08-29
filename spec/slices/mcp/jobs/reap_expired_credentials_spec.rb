# frozen_string_literal: true

RSpec.describe MCP::Jobs::ReapExpiredCredentials, type: :request do
  let(:client) { mcp_create(:oauth_client) }
  let(:verifier) { MCP::OAuth::Secret.generate }

  def code_row(*traits) = mcp_create(:oauth_code, *traits, oauth_client_id: client.id)

  def codes = MCP::Slice["db.rom"].relations[:oauth_codes]

  def mcp_create(name, *, **) = Spec::DB::Factories[:mcp].create(name, *, **)

  def reap = described_class.new.perform

  def token_row(*traits) = mcp_create(:oauth_token, *traits, oauth_client_id: client.id)

  def tokens = MCP::Slice["db.rom"].relations[:oauth_tokens]

  it "runs on the schedule the worker reads" do
    expect(Object.const_get(sidekiq_schedule("reap_expired_credentials").fetch("class"))).to eq(described_class)
  end

  describe "authorization codes" do
    it "deletes a code past its expiry" do
      code_row(:expired)
      reap

      expect(codes.count).to eq(0)
    end

    it "deletes a used code once it has expired" do
      code_row(:used, :expired)
      reap

      expect(codes.count).to eq(0)
    end

    it "keeps a code that has not expired" do
      code_row
      reap

      expect(codes.count).to eq(1)
    end

    it "keeps a used code that has not expired" do
      code_row(:used)
      reap

      expect(codes.count).to eq(1)
    end

    it "still revokes the client when a kept code is replayed" do
      code = mcp_authorization_code(client, verifier:)
      mcp_exchange(client, code, verifier:)
      reap
      mcp_exchange(client, code, verifier:)

      expect(tokens.live.count).to eq(0)
    end
  end

  describe "tokens" do
    it "deletes an access token past its expiry" do
      token_row(:expired)
      reap

      expect(tokens.count).to eq(0)
    end

    it "deletes a refresh token past its expiry" do
      token_row(:refresh, :expired)
      reap

      expect(tokens.count).to eq(0)
    end

    it "deletes a revoked refresh token once it has expired" do
      token_row(:refresh, :revoked, :expired)
      reap

      expect(tokens.count).to eq(0)
    end

    it "keeps a live token" do
      token_row
      reap

      expect(tokens.count).to eq(1)
    end

    it "keeps a revoked refresh token that has not expired" do
      token_row(:refresh, :revoked)
      reap

      expect(tokens.count).to eq(1)
    end

    it "still revokes the client when a kept refresh token is replayed" do
      spent = mcp_connect(client, verifier:).fetch("refresh_token")
      mcp_refresh(client, spent)
      reap
      mcp_refresh(client, spent)

      expect(tokens.live.count).to eq(0)
    end
  end

  it "leaves another client's live rows alone" do
    token_row(:expired)
    other = mcp_create(:oauth_client)
    mcp_create(:oauth_token, oauth_client_id: other.id)
    reap

    expect(tokens.to_a.map { it[:oauth_client_id] }).to eq([other.id])
  end
end
