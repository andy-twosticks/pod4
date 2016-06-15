source 'https://rubygems.org'


gemspec


group :development, :test do

  # for bundler, management, etc etc
  gem "bundler", "~> 1.11"
  gem "rake",    "~> 10.5"
  gem "rspec",   "~> 3.4"


  # For testing
  gem "sequel",          "~> 4.35"
  gem "nebulous_stomp" , "~> 2"

  platforms :mri do
    gem "sqlite3",         "~> 1.3"
    gem "tiny_tds",        "~> 0"
    gem "pg",              "~> 0"
  end

  platforms :jruby do
    gem "jruby-lint"
  end


  # Development tools
  platforms :mri do
    gem "rdoc"
    gem "pry"
    gem "pry-doc"
    gem "ripper-tags"
  end
  
end



