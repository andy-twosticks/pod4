require "bundler/gem_tasks"
require "rspec/core/rake_task"
require 'rdoc/task'

RSpec::Core::RakeTask.new(:spec)

namespace :rdoc do
  RDoc::Task.new do |rdoc|
    rdoc.main = "README.md"
    rdoc.rdoc_files.include("*.md", "lib/*", "md/*")
    rdoc.rdoc_dir = "doc"
  end

  desc "Push doc to HARS"
  task :hars do
    sh "rsync -aP --delete doc/ /home/hars/hars/public/pod4"
  end

end

desc "Start Guard"
task :guard do
  sh "bundle exec guard"
end

desc "Update vim tag data"
task :retag do
  sh "ripper-tags -R"
end

