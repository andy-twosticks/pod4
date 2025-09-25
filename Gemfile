source 'https://rubygems.org'

gemspec


group :development, :test do

  # for bundler, management, etc etc
  gem "bundler", "~> 2.2"
  gem "rake",    "~> 13.0" 
  gem "rspec",   "~> 3.10"
  gem 'pry'
  gem "pry-doc"
  gem "base64"
  gem "logger"

  # For testing
  gem "sequel",         "~> 5.4" 
  gem "nebulous_stomp", "~> 3"

  platforms :ruby do
    gem "sqlite3",  "~> 1.4"
    gem "tiny_tds", "~> 2.1"
    gem "pg"
  end

  platforms :jruby do
    gem "jruby-lint"
    gem "jeremyevans-postgres-pr"
    gem 'jdbc-mssqlserver'

    # Note that this gem is part of a larger project, for Activerecord, and their version history
    # makes no sense at all.  See the RubyGems site to make sense of that.  Note: there are
    # alternative gems. But this is by the jRuby team; so that's a powerful reason to tolerate BS.
    # If you want to go back to the previous version we used you'll have to pin it here; Bundler
    # can't figure out their version history, either.
    gem 'jdbc-postgres', '42.2.14'
  end


  # Development tools
  platforms :ruby do
    gem "rdoc"
    gem "ripper-tags"
  end
  
end



