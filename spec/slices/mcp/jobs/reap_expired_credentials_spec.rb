# frozen_string_literal: true

RSpec.describe MCP::Jobs::ReapExpiredCredentials do
  let(:client) { mcp_create(:oauth_client) }
  let(:verifier) { Blog::Types::NewSecret[] }

  def clients = MCP::Slice["db.rom"].relations[:oauth_clients]

  def code_row(*traits) = mcp_create(:oauth_code, *traits, oauth_client_id: client.id)

  def codes = MCP::Slice["db.rom"].relations[:oauth_codes]

  def days_ago(days) = Time.now - (days * 24 * 60 * 60)

  def mcp_create(name, *, **) = Spec::DB::Factories[:mcp].create(name, *, **)

  def reap = described_class.new.perform

  def token_row(*traits) = mcp_create(:oauth_token, *traits, oauth_client_id: client.id)

  def tokens = MCP::Slice["db.rom"].relations[:oauth_tokens]

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

    it "still revokes the client when a kept code is replayed", type: :request do
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

    it "still revokes the client when a kept refresh token is replayed", type: :request do
      spent = mcp_connect(client, verifier:).fetch("refresh_token")
      mcp_refresh(client, spent)
      reap
      mcp_refresh(client, spent)

      expect(tokens.live.count).to eq(0)
    end
  end

  describe "clients" do
    def idle_client(**) = mcp_create(:oauth_client, created_at: days_ago(91), **)

    it "deletes a client that registered over 90 days ago and never connected" do
      idle = idle_client
      reap

      expect(clients.by_pk(idle.id).count).to eq(0)
    end

    it "deletes a client that last connected over 90 days ago and holds no live token" do
      idle = idle_client(last_used_at: days_ago(91))
      mcp_create(:oauth_token, :refresh, :expired, oauth_client_id: idle.id)
      reap

      expect(clients.by_pk(idle.id).count).to eq(0)
    end

    it "deletes an idle client whose only unexpired token is revoked" do
      idle = idle_client
      revoked = mcp_create(:oauth_token, :refresh, :revoked, oauth_client_id: idle.id)
      reap

      expect([clients.by_pk(idle.id).count, tokens.by_pk(revoked.id).count]).to eq([0, 0])
    end

    it "deletes a client that registered over a day ago and never received a code or token" do
      unclaimed = mcp_create(:oauth_client, created_at: days_ago(2))
      reap

      expect(clients.by_pk(unclaimed.id).count).to eq(0)
    end

    it "keeps a client that registered inside a day" do
      fresh = mcp_create(:oauth_client, created_at: Time.now - (23 * 60 * 60))
      reap

      expect(clients.by_pk(fresh.id).count).to eq(1)
    end

    it "keeps a client inside 90 days that holds a code" do
      approved = mcp_create(:oauth_client, created_at: days_ago(2))
      mcp_create(:oauth_code, :used, oauth_client_id: approved.id)
      reap

      expect(clients.by_pk(approved.id).count).to eq(1)
    end

    it "keeps a client inside 90 days that holds only a revoked token" do
      revoked = mcp_create(:oauth_client, created_at: days_ago(2))
      mcp_create(:oauth_token, :refresh, :revoked, oauth_client_id: revoked.id)
      reap

      expect(clients.by_pk(revoked.id).count).to eq(1)
    end

    it "keeps a client inside 90 days that has connected, once its tokens have lapsed" do
      lapsed = mcp_create(:oauth_client, created_at: days_ago(89), last_used_at: days_ago(60))
      reap

      expect(clients.by_pk(lapsed.id).count).to eq(1)
    end

    it "keeps a client that connected inside 90 days" do
      used = idle_client(last_used_at: days_ago(89))
      reap

      expect(clients.by_pk(used.id).count).to eq(1)
    end

    it "keeps an idle client holding a live access token" do
      held = idle_client(last_used_at: days_ago(91))
      mcp_create(:oauth_token, oauth_client_id: held.id)
      reap

      expect(clients.by_pk(held.id).count).to eq(1)
    end

    it "keeps an idle client holding a live refresh token" do
      held = idle_client(last_used_at: days_ago(91))
      mcp_create(:oauth_token, :refresh, oauth_client_id: held.id)
      reap

      expect(clients.by_pk(held.id).count).to eq(1)
    end

    it "keeps an idle client the owner has just approved", type: :request do
      approved = idle_client
      code = mcp_authorization_code(approved, verifier:)
      reap

      expect(mcp_exchange(approved, code, verifier:)).to include("access_token")
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
