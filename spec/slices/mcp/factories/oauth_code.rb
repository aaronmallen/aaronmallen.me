# frozen_string_literal: true

Spec::DB::Factories[:mcp].define(:oauth_code) do |f|
  f.sequence(:code_digest) { |n| Blog::SecretToken.digest("code-#{n}") }
  f.redirect_uri "https://claude.ai/api/mcp/auth_callback"
  f.code_challenge { MCP::OAuth::PKCE.challenge(Blog::SecretToken.generate) }
  f.expires_at { Time.now + 60 }

  f.trait :expired do |t|
    t.expires_at { Time.now - 1 }
  end

  f.trait :used do |t|
    t.used_at { Time.now }
  end
end
