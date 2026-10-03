# frozen_string_literal: true

Social::Slice.register_provider :links do
  start do
    register "links.tagger", Social::LinkTagger.new(target["settings"])
  end
end
