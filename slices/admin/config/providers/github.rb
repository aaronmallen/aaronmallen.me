# frozen_string_literal: true

Admin::Slice.register_provider :github do
  start do
    register "github.auth", Admin::Providers::GitHubAuthProvider.auth(target["settings"])
  end
end
