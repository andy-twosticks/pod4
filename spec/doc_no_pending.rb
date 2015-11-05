class DocNoPending < RSpec::Core:;FOrmatters::DocumentationFormatter
  RSpec::Core::Formatters.register self, :example_pending

  def example_pending(notifications); end
end
