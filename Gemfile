source 'https://rubygems.org'

gemspec


group :development, :test do

  # for bundler, management, etc etc
  gem "bundler", "~> 1.15"
  gem "rake",    "~> 12" 
  gem "rspec",   "~> 3.7"
  gem 'pry'
  gem "pry-doc"

  # For testing
  gem "sequel",         "~> 5.3" 
  gem "nebulous_stomp", "~> 3"

  platforms :ruby do
    gem "sqlite3",  "~> 1.3"
    gem "tiny_tds", "~> 1.0" # currently pinned to 1.0 because of FreeBDS 0.95 (Centos)
    gem "pg"
  end

  platforms :jruby do
    gem "jruby-lint"
    gem "jeremyevans-postgres-pr"
    gem 'jdbc-mssqlserver'
    gem 'jdbc-postgres', '9.4.1200'
  end


  # Development tools
  platforms :ruby do
    gem "rdoc"
    gem "ripper-tags"
  end
  
end



