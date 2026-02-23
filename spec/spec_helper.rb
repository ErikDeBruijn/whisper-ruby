require "whisper"

RSpec.configure do |config|
  config.filter_run_excluding e2e: true unless ENV["RUN_E2E"]

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.around(:each, :e2e) do |example|
    WebMock.allow_net_connect! if defined?(WebMock)
    example.run
    WebMock.disable_net_connect! if defined?(WebMock)
  end

  config.order = :random
  Kernel.srand config.seed
end
