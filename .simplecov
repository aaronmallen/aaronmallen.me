# frozen_string_literal: true

SimpleCov.configure do
  cover "**/*.rb"
  enable_coverage :branch
  skip "/config/"
  skip "/spec/"
  skip "/tmp/"

  group "lib/blog", "lib/blog/"
  Dir.children(File.join(root, "slices")).sort.each do |slice|
    group(slice) do |file|
      file.filename.start_with?(File.join(root, "slices", slice, ""), File.join(root, "lib", slice, ""))
    end
  end
end

SimpleCov.profiles.define "floor" do
  minimum_coverage line: 98.3, branch: 90.8
end
