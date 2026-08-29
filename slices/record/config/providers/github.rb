# frozen_string_literal: true

Record::Slice.register_provider :github do
  start do
    register "github.client", Record::Providers::GitHubProvider.client(target["settings"], target["http"])
  end
end
