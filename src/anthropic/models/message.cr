require "json"

struct Anthropic::Message
  include JSON::Serializable

  enum Role
    User
    Assistant

    def to_json(json : JSON::Builder) : Nil
      json.string(to_s.downcase)
    end
  end

  getter role : Role
  getter content : String | Array(TextBlock)

  def initialize(@role : Role, @content : String | Array(TextBlock))
  end

  def self.user(content : String) : Message
    new(Role::User, content)
  end

  def self.assistant(content : String) : Message
    new(Role::Assistant, content)
  end
end
