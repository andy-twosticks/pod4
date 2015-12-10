source 'https://rubygems.org'
gemspec

# Tell bundler where to find Nebulous, a development dependancy.
# dependancy in the Gemfile.  This wouldn't work when including Pod4 in a
# Gemfile in another project ... but we specifically say that you need to put
# Nebulous in the gemfile seperately in that case. We wouldn't want to make
# Nebulous a production dependancy; the user of Pod4 might not need
# nebulous_interface.

gem "nebulous", :git => "http://scm.jhallpr.com/gems/nebulous", :branch => 'master'
