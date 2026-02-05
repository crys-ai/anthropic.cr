# Placeholder - implemented in Phase 1.10
class Anthropic::Messages::API
  def initialize(@client : Client)
  end

  def create(request : Request) : Response
    raise "Not implemented"
  end
end
