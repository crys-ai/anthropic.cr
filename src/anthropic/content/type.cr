module Anthropic::Content
  enum Type
    Text
    Image
    ToolUse
    ToolResult
    Thinking

    def to_json(json : JSON::Builder) : Nil
      json.string(to_s.underscore)
    end
  end
end
