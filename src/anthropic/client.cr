# Placeholder - implemented in Phase 1.4
class Anthropic::Client
  def initialize(api_key : String? = nil)
  end

  def messages : Messages::API
    Messages::API.new(self)
  end
end
