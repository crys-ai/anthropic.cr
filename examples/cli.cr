require "../src/anthropic"
require "option_parser"

model = Anthropic::Model.opus
max_tokens = 1024
system_prompt : String? = nil
verbose = false

command = ARGV.shift?
text = ARGV.shift?

OptionParser.parse do |parser|
  parser.banner = "Usage: crystal run examples/cli.cr -- message <text> [options]"

  parser.on("-m MODEL", "--model=MODEL", "Model (opus, sonnet, haiku)") do |value|
    model = Anthropic::Model.parse(value)
  end

  parser.on("-t TOKENS", "--max-tokens=TOKENS", "Max tokens (default: #{max_tokens})") do |value|
    max_tokens = value.to_i
  end

  parser.on("-s SYSTEM", "--system=SYSTEM", "System prompt") do |value|
    system_prompt = value
  end

  parser.on("-v", "--verbose", "Show token usage") do
    verbose = true
  end

  parser.on("-h", "--help", "Show help") do
    puts parser
    puts "\nAvailable models:"
    Anthropic::Model.each { |value| puts "  #{value.to_s.underscore}" }
    exit
  end
end

if command != "message" || text.nil? || text.empty?
  STDERR.puts "Usage: crystal run examples/cli.cr -- message <text> [options]"
  STDERR.puts "Example: crystal run examples/cli.cr -- message \"Hello\" -m opus"
  exit 1
end

begin
  client = Anthropic::Client.new

  response = client.messages.create(
    model: model,
    messages: [Anthropic::Message.user(text)],
    max_tokens: max_tokens,
    system: system_prompt
  )

  puts response.text
  if verbose
    STDERR.puts "---"
    STDERR.puts "model: #{response.model}"
    STDERR.puts "tokens: #{response.usage.input_tokens} in / #{response.usage.output_tokens} out"
  end
rescue ex : ArgumentError
  STDERR.puts "Error: #{ex.message}"
  exit 1
rescue ex : Anthropic::APIError
  STDERR.puts "API Error: #{ex.message}"
  exit 1
end
