#require "bundler/gem_tasks"
#require "rspec/core/rake_task"

#RSpec::Core::RakeTask.new(:spec)

desc "Push doc to HARS"
task :hars do
  sh "rsync -aP --delete doc/ /home/hars/hars/public/pod4"
end

desc "Update vim tag data"
task :retag do
  sh "ripper-tags -R"
end

namespace :rspec do

  desc "run tests (mri)"
  task :mri do
    sh "rspec spec/common spec/mri"
  end

  desc "run tests (jRuby)"
  task :jruby do
    sh "rspec spec/common spec/jruby"
  end

end
