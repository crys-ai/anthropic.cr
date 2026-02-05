# Placeholder - implemented in Phase 1.8
struct Anthropic::Messages::Request
  def initialize(
    @model : String,
    @messages : Array(Message),
    @max_tokens : Int32,
    **options
  )
  end
end
