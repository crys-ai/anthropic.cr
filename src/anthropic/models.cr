enum Anthropic::Model
  # Claude 4.5 models (latest)
  ClaudeOpus4_5
  ClaudeSonnet4_5

  # Claude 4 models
  ClaudeOpus4
  ClaudeSonnet4

  # Claude 3.5 models
  ClaudeSonnet3_5
  ClaudeHaiku3_5

  # Returns the API model identifier string.
  def to_api_string : String
    case self
    in ClaudeOpus4_5   then "claude-opus-4-5-20251101"
    in ClaudeSonnet4_5 then "claude-sonnet-4-5-20251101"
    in ClaudeOpus4     then "claude-opus-4-20251101"
    in ClaudeSonnet4   then "claude-sonnet-4-20251101"
    in ClaudeSonnet3_5 then "claude-3-5-sonnet-20260101"
    in ClaudeHaiku3_5  then "claude-3-5-haiku-20260101"
    end
  end

  def to_json(json : JSON::Builder) : Nil
    json.string(to_api_string)
  end

  # Aliases for convenience
  def self.opus : Model
    ClaudeOpus4_5
  end

  def self.sonnet : Model
    ClaudeSonnet4_5
  end

  def self.haiku : Model
    ClaudeHaiku3_5
  end

  # Parses a model name from a string, supporting friendly aliases
  # ("opus", "sonnet", "haiku") in addition to the standard enum names
  # accepted by `Model.parse` (e.g. "ClaudeOpus4_5", "claude_opus_4_5").
  def self.from_friendly(value : String) : Model
    case value.downcase
    when "opus"   then opus
    when "sonnet" then sonnet
    when "haiku"  then haiku
    else               parse(value)
    end
  end
end
