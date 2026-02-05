# Placeholder - implemented in Phase 1.7
struct Anthropic::Message
  def initialize(@role : Role, @content : String)
  end

  def self.user(content : String) : Message
    new(Role::User, content)
  end

  def self.assistant(content : String) : Message
    new(Role::Assistant, content)
  end

  enum Role
    User
    Assistant
  end
end
