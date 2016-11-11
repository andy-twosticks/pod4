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

  desc "run one test (pass as parameter)"
  task :one do |task, args|

    if args.extras.count > 0 # rake rspec[path/to/file]
      sh "rspec #{args.extras.first}"

    elsif ARGV.count == 2 && File.exist?(ARGV[1])  # rake rspec path/to/file
      sh "rspec #{ARGV[1]}"

    else
      raise "You need to specify a test"
    end

  end

end

