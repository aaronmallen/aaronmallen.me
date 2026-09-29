# frozen_string_literal: true

Record::Slice.register_provider :linear do
  start do
    register "linear.client", Record::Providers::LinearProvider.client(target["settings"], target["http"])
  end
end
