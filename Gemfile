source 'https://rubygems.org'


gemspec


group :development, :test do

  # for bundler, management, etc etc
  gem "bundler", "~> 1.11"
  gem "rake",    "~> 10.5"
  gem "rspec",   "~> 3.4"
  gem 'pry'
  gem "pry-doc"

  # For testing
  gem "sequel",         "~> 4.35"
  gem "nebulous_stomp", "~> 2"

  platforms :ruby do
    gem "sqlite3",  "~> 1.3"
    gem "tiny_tds", "~> 0"
    gem "pg"
  end

  platforms :jruby do
    gem "jruby-lint"
    gem "pg_jruby"
  end


  # Development tools
  platforms :ruby do
    gem "rdoc"
    gem "ripper-tags"
  end
  
end



