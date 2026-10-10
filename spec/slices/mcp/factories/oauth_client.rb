# frozen_string_literal: true

require "digest"

Spec::DB::Factories[:mcp].define(:oauth_client) do |f|
  f.sequence(:client_id) { |n| "11111111-0000-4000-8000-#{format('%012d', n)}" }
  f.client_name { Faker::App.name }
  f.redirect_uris { %w[https://claude.ai/api/mcp/auth_callback] }
  f.grant_types { %w[authorization_code refresh_token] }
  f.response_types { %w[code] }
  f.token_endpoint_auth_method "none"
  f.sequence(:visitor_hash) { |n| Digest::SHA256.hexdigest("registrant-#{n}") }
end
