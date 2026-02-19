require "../../spec_helper"

describe Anthropic::Models::API do
  describe "#list" do
    it "returns a page of models" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "claude-sonnet-4-6", display_name: "Claude Sonnet 4.6", created_at: "2025-02-24T00:00:00Z", type: "model"},
              {id: "claude-haiku-4-5-20251001", display_name: "Claude Haiku 4.5", created_at: "2025-10-01T00:00:00Z", type: "model"},
            ],
            has_more: false,
            first_id: "claude-sonnet-4-6",
            last_id:  "claude-haiku-4-5-20251001",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      response = client.models.list

      response.data.size.should eq(2)
      response.data[0].id.should eq("claude-sonnet-4-6")
      response.data[0].display_name.should eq("Claude Sonnet 4.6")
      response.data[1].id.should eq("claude-haiku-4-5-20251001")
      response.has_more?.should be_false
      response.first_id.should eq("claude-sonnet-4-6")
      response.last_id.should eq("claude-haiku-4-5-20251001")
    end

    it "handles pagination flag" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return(
          status: 200,
          body: {data: [{id: "model-1", display_name: "Model 1", created_at: "2025-01-01T00:00:00Z", type: "model"}], has_more: true, first_id: "model-1", last_id: "model-1"}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      response = client.models.list
      response.has_more?.should be_true
    end

    it "handles empty list" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return(
          status: 200,
          body: {data: [] of String, has_more: false}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      response = client.models.list
      response.data.should be_empty
      response.has_more?.should be_false
    end

    it "raises NotFoundError on 404" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return(
          status: 404,
          body: TestHelpers.error_json("not_found_error", "Not found"),
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      expect_raises(Anthropic::NotFoundError) do
        client.models.list
      end
    end

    it "raises AuthenticationError on 401" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return(
          status: 401,
          body: TestHelpers.error_json("authentication_error", "Invalid API key"),
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      expect_raises(Anthropic::AuthenticationError) do
        client.models.list
      end
    end

    it "forwards request_options to client" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .with(headers: {"X-Custom-Header" => "custom-value"})
        .to_return(
          status: 200,
          body: {data: [] of String, has_more: false}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Custom-Header" => "custom-value"}
      )

      response = client.models.list(request_options: options)
      response.should be_a(Anthropic::Page(Anthropic::ModelInfo))
    end

    it "forwards beta headers via request_options" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .with(headers: {"anthropic-beta" => "models-beta"})
        .to_return(
          status: 200,
          body: {data: [] of String, has_more: false}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(beta_headers: ["models-beta"])

      client.models.list(request_options: options)
    end

    it "accepts pagination params" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models?limit=10&after_id=model-1")
        .to_return(
          status: 200,
          body: {data: [] of String, has_more: false}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      params = Anthropic::ListParams.new(limit: 10, after_id: "model-1")
      response = client.models.list(params)
      response.should be_a(Anthropic::Page(Anthropic::ModelInfo))
    end
  end

  describe "#retrieve" do
    it "returns a specific model" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models/claude-sonnet-4-6")
        .to_return(
          status: 200,
          body: {id: "claude-sonnet-4-6", display_name: "Claude Sonnet 4.6", created_at: "2025-02-24T00:00:00Z", type: "model"}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      model = client.models.retrieve("claude-sonnet-4-6")

      model.id.should eq("claude-sonnet-4-6")
      model.display_name.should eq("Claude Sonnet 4.6")
      model.created_at.should eq("2025-02-24T00:00:00Z")
      model.type.should eq("model")
    end

    it "raises NotFoundError for unknown model" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models/unknown-model")
        .to_return(
          status: 404,
          body: TestHelpers.error_json("not_found_error", "Model not found"),
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      expect_raises(Anthropic::NotFoundError) do
        client.models.retrieve("unknown-model")
      end
    end

    it "forwards request_options to client" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models/claude-sonnet-4-6")
        .with(headers: {"X-Retrieve-Header" => "retrieve-value"})
        .to_return(
          status: 200,
          body: {id: "claude-sonnet-4-6", display_name: "Claude Sonnet 4.6", created_at: "2025-02-24T00:00:00Z", type: "model"}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Retrieve-Header" => "retrieve-value"}
      )

      model = client.models.retrieve("claude-sonnet-4-6", options)
      model.id.should eq("claude-sonnet-4-6")
    end

    it "encodes model_id with slashes in path" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models/model%2Fwith%2Fslashes")
        .to_return(
          status: 200,
          body: {id: "model/with/slashes", display_name: "Slashed Model", created_at: "2025-01-01T00:00:00Z", type: "model"}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      model = client.models.retrieve("model/with/slashes")
      model.id.should eq("model/with/slashes")
    end

    it "encodes model_id with query and fragment characters in path" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models/id%3Fquery%23fragment")
        .to_return(
          status: 200,
          body: {id: "id?query#fragment", display_name: "Special Model", created_at: "2025-01-01T00:00:00Z", type: "model"}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      model = client.models.retrieve("id?query#fragment")
      model.id.should eq("id?query#fragment")
    end
  end

  describe "#list_all" do
    it "returns an AutoPaginator for lazy iteration" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "claude-sonnet-4-6", display_name: "Claude Sonnet 4.6", created_at: "2025-01-01T00:00:00Z", type: "model"},
            ],
            has_more: false,
            first_id: "claude-sonnet-4-6",
            last_id:  "claude-sonnet-4-6",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      paginator = client.models.list_all

      paginator.should be_a(Anthropic::AutoPaginator(Anthropic::ModelInfo))
      models = paginator.to_a
      models.size.should eq(1)
      models[0].id.should eq("claude-sonnet-4-6")
    end

    it "iterates across multiple pages using after_id cursor" do
      # First page
      WebMock.stub(:get, "https://api.anthropic.com/v1/models?limit=1")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "model-1", display_name: "Model 1", created_at: "2025-01-01T00:00:00Z", type: "model"},
            ],
            has_more: true,
            first_id: "model-1",
            last_id:  "model-1",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      # Second page
      WebMock.stub(:get, "https://api.anthropic.com/v1/models?after_id=model-1&limit=1")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "model-2", display_name: "Model 2", created_at: "2025-01-02T00:00:00Z", type: "model"},
            ],
            has_more: false,
            first_id: "model-2",
            last_id:  "model-2",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      paginator = client.models.list_all(limit: 1)

      ids = [] of String
      paginator.each { |model| ids << model.id }

      ids.should eq(["model-1", "model-2"])
    end

    it "handles empty list" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return(
          status: 200,
          body: {data: [] of String, has_more: false}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      paginator = client.models.list_all

      models = paginator.to_a
      models.should be_empty
    end

    it "supports Enumerable methods" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "claude-sonnet-4-6", display_name: "Claude Sonnet 4.6", created_at: "2025-01-01T00:00:00Z", type: "model"},
              {id: "claude-haiku-4-5", display_name: "Claude Haiku 4.5", created_at: "2025-01-02T00:00:00Z", type: "model"},
            ],
            has_more: false,
            first_id: "claude-sonnet-4-6",
            last_id:  "claude-haiku-4-5",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client

      # Test map
      ids = client.models.list_all.map(&.id)
      ids.should eq(["claude-sonnet-4-6", "claude-haiku-4-5"])

      # Test select
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "claude-sonnet-4-6", display_name: "Claude Sonnet 4.6", created_at: "2025-01-01T00:00:00Z", type: "model"},
              {id: "claude-haiku-4-5", display_name: "Claude Haiku 4.5", created_at: "2025-01-02T00:00:00Z", type: "model"},
            ],
            has_more: false,
            first_id: "claude-sonnet-4-6",
            last_id:  "claude-haiku-4-5",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      haiku_models = client.models.list_all.select(&.id.includes?("haiku"))
      haiku_models.size.should eq(1)
      haiku_models.first.id.should eq("claude-haiku-4-5")
    end

    it "passes limit parameter to fetcher" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models?limit=5")
        .to_return(
          status: 200,
          body: {data: [] of String, has_more: false}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      paginator = client.models.list_all(limit: 5)
      paginator.to_a
    end

    it "forwards request_options to each paginated list call" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .with(headers: {"X-Paginate-Header" => "paginate-value"})
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "model-1", display_name: "Model 1", created_at: "2025-01-01T00:00:00Z", type: "model"},
            ],
            has_more: false,
            first_id: "model-1",
            last_id:  "model-1",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Paginate-Header" => "paginate-value"}
      )

      models = client.models.list_all(request_options: options).to_a
      models.size.should eq(1)
      models[0].id.should eq("model-1")
    end

    it "forwards request_options across multiple pages" do
      # First page
      WebMock.stub(:get, "https://api.anthropic.com/v1/models?limit=1")
        .with(headers: {"X-Multi-Page" => "yes"})
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "model-1", display_name: "Model 1", created_at: "2025-01-01T00:00:00Z", type: "model"},
            ],
            has_more: true,
            first_id: "model-1",
            last_id:  "model-1",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      # Second page
      WebMock.stub(:get, "https://api.anthropic.com/v1/models?after_id=model-1&limit=1")
        .with(headers: {"X-Multi-Page" => "yes"})
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "model-2", display_name: "Model 2", created_at: "2025-01-02T00:00:00Z", type: "model"},
            ],
            has_more: false,
            first_id: "model-2",
            last_id:  "model-2",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Multi-Page" => "yes"}
      )

      ids = [] of String
      client.models.list_all(limit: 1, request_options: options).each do |model|
        ids << model.id
      end

      ids.should eq(["model-1", "model-2"])
    end

    it "forwards beta headers via request_options through pagination" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .with(headers: {"anthropic-beta" => "models-2025-01-01"})
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "beta-model", display_name: "Beta Model", created_at: "2025-01-01T00:00:00Z", type: "model"},
            ],
            has_more: false,
            first_id: "beta-model",
            last_id:  "beta-model",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(beta_headers: ["models-2025-01-01"])

      models = client.models.list_all(request_options: options).to_a
      models.size.should eq(1)
      models[0].id.should eq("beta-model")
    end
  end
end
