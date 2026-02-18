enum Anthropic::Model
  # Claude 4.6 models (latest)
  ClaudeOpus4_6
  ClaudeSonnet4_6

  # Claude 4.5 models
  ClaudeOpus4_5
  ClaudeSonnet4_5
  ClaudeHaiku4_5

  # Claude 4 models
  ClaudeOpus4
  ClaudeSonnet4

  # Returns the mapping of enum values to their API string identifiers.
  def self.api_strings : Hash(Model, String)
    {
      ClaudeOpus4_6   => "claude-opus-4-6",
      ClaudeSonnet4_6 => "claude-sonnet-4-6",
      ClaudeOpus4_5   => "claude-opus-4-5-20251101",
      ClaudeSonnet4_5 => "claude-sonnet-4-5-20250929",
      ClaudeHaiku4_5  => "claude-haiku-4-5-20251001",
      ClaudeOpus4     => "claude-opus-4-20250514",
      ClaudeSonnet4   => "claude-sonnet-4-20250514",
    }
  end

  # Returns the API model identifier string.
  def to_api_string : String
    self.class.api_strings[self]
  end

  def to_json(json : JSON::Builder) : Nil
    json.string(to_api_string)
  end

  # Aliases for convenience (point to latest versions)
  def self.opus : Model
    ClaudeOpus4_6
  end

  def self.sonnet : Model
    ClaudeSonnet4_6
  end

  def self.haiku : Model
    ClaudeHaiku4_5
  end

  # Parses a model name from a string, supporting friendly aliases
  # ("opus", "sonnet", "haiku") in addition to the standard enum names
  # accepted by `Model.parse` (e.g. "ClaudeOpus4_6", "claude_opus_4_6").
  def self.from_friendly(value : String) : Model
    case value.downcase
    when "opus"   then opus
    when "sonnet" then sonnet
    when "haiku"  then haiku
    else               parse(value)
    end
  end
end
