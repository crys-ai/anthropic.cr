require "../src/anthropic"
require "option_parser"

model = Anthropic::Model.opus
max_tokens = 1024
system_prompt : String? = nil
verbose = false
show_help = false

parser = OptionParser.new do |parser|
  parser.banner = "Usage: crystal run examples/cli.cr -- message <text> [options]"

  parser.on("-m MODEL", "--model=MODEL", "Model (opus, sonnet, haiku, or enum e.g. claude_opus_4_5)") do |value|
    begin
      model = Anthropic::Model.from_friendly(value)
    rescue ex : ArgumentError
      raise ArgumentError.new("Invalid model '#{value}'. Use opus, sonnet, haiku, or enum e.g. claude_opus_4_5")
    end
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
    show_help = true
  end
end

begin
  parser.parse
rescue ex : OptionParser::Exception
  STDERR.puts "Error: #{ex.message}"
  STDERR.puts parser
  exit 1
rescue ex : ArgumentError
  STDERR.puts "Error: #{ex.message}"
  STDERR.puts parser
  exit 1
end

if show_help
  puts parser
  puts "\nAvailable models:"
  puts "  Aliases:  opus, sonnet, haiku"
  puts "  Enum:     #{Anthropic::Model.values.map(&.to_s.underscore).join(", ")}"
  exit
end

command = ARGV.shift?
text = ARGV.shift?

if command != "message" || text.nil? || text.empty?
  STDERR.puts parser
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
