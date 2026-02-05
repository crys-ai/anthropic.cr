require "json"

struct Anthropic::TextBlock
  include JSON::Serializable

  property type : String = "text"
  property text : String

  def initialize(@text)
  end
end
