require "../../spec_helper"

describe Anthropic::ModelInfo do
  describe "JSON deserialization" do
    it "parses a model info JSON object" do
      json = <<-JSON
        {
          "id": "claude-sonnet-4-6",
          "display_name": "Claude Sonnet 4.6",
          "created_at": "2025-02-24T00:00:00Z",
          "type": "model"
        }
        JSON

      model = Anthropic::ModelInfo.from_json(json)
      model.id.should eq("claude-sonnet-4-6")
      model.display_name.should eq("Claude Sonnet 4.6")
      model.created_at.should eq("2025-02-24T00:00:00Z")
      model.type.should eq("model")
    end
  end

  describe "JSON round-trip" do
    it "survives to_json -> from_json" do
      model = Anthropic::ModelInfo.new(
        id: "claude-opus-4-5-20251101",
        display_name: "Claude Opus 4.5",
        created_at: "2025-11-01T00:00:00Z",
      )

      parsed = Anthropic::ModelInfo.from_json(model.to_json)
      parsed.id.should eq("claude-opus-4-5-20251101")
      parsed.display_name.should eq("Claude Opus 4.5")
      parsed.type.should eq("model")
    end
  end

  describe "#initialize" do
    it "defaults type to model" do
      model = Anthropic::ModelInfo.new(
        id: "test-model",
        display_name: "Test Model",
        created_at: "2025-01-01T00:00:00Z",
      )
      model.type.should eq("model")
    end

    it "accepts custom type" do
      model = Anthropic::ModelInfo.new(
        id: "test-model",
        display_name: "Test Model",
        created_at: "2025-01-01T00:00:00Z",
        type: "custom",
      )
      model.type.should eq("custom")
    end
  end
end
