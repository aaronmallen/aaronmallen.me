# frozen_string_literal: true

Spec::DB::Factories[:mcp].define(:oauth_token) do |f|
  f.type "access"
  f.sequence(:token_digest) { |n| Blog::Types::SecretDigest["token-#{n}"] }
  f.expires_at { Time.now + 3600 }

  f.trait :expired do |t|
    t.expires_at { Time.now - 1 }
  end

  f.trait :refresh do |t|
    t.type "refresh"
  end

  f.trait :revoked do |t|
    t.revoked_at { Time.now }
  end
end
