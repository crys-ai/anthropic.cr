require "../../spec_helper"

describe Anthropic::MessageBatch do
  describe "JSON deserialization" do
    it "parses a batch response" do
      json = <<-JSON
        {
          "id": "batch_123",
          "type": "message_batch",
          "processing_status": "in_progress",
          "request_counts": {
            "processing": 5,
            "succeeded": 10,
            "errored": 2,
            "canceled": 0,
            "expired": 0
          },
          "created_at": "2025-01-01T00:00:00Z",
          "ended_at": "2025-01-02T00:00:00Z",
          "expires_at": "2025-01-08T00:00:00Z"
        }
        JSON

      batch = Anthropic::MessageBatch.from_json(json)
      batch.id.should eq("batch_123")
      batch.type.should eq("message_batch")
      batch.processing_status.should eq("in_progress")
      batch.request_counts.processing.should eq(5)
      batch.request_counts.succeeded.should eq(10)
      batch.request_counts.errored.should eq(2)
      batch.request_counts.canceled.should eq(0)
      batch.created_at.should eq("2025-01-01T00:00:00Z")
      batch.ended_at.should eq("2025-01-02T00:00:00Z")
      batch.expires_at.should eq("2025-01-08T00:00:00Z")
    end

    it "parses with optional fields absent" do
      json = <<-JSON
        {
          "id": "batch_456",
          "type": "message_batch",
          "processing_status": "in_progress",
          "request_counts": {
            "processing": 3,
            "succeeded": 0,
            "errored": 0,
            "canceled": 0,
            "expired": 0
          },
          "created_at": "2025-01-01T00:00:00Z"
        }
        JSON

      batch = Anthropic::MessageBatch.from_json(json)
      batch.id.should eq("batch_456")
      batch.ended_at.should be_nil
      batch.expires_at.should be_nil
      batch.archived_at.should be_nil
      batch.cancel_initiated_at.should be_nil
      batch.results_url.should be_nil
    end
  end
end

describe Anthropic::MessageBatchDeleted do
  describe "JSON deserialization" do
    it "parses a batch deleted response" do
      json = <<-JSON
        {
          "id": "batch_123",
          "type": "message_batch_deleted"
        }
        JSON

      deleted = Anthropic::MessageBatchDeleted.from_json(json)
      deleted.id.should eq("batch_123")
      deleted.type.should eq("message_batch_deleted")
    end
  end
end

describe Anthropic::CreateMessageBatchRequest do
  describe "#initialize" do
    it "creates with batch requests" do
      requests = [
        Anthropic::CreateMessageBatchRequest::BatchRequest.new(
          custom_id: "req_1",
          params: {"model" => JSON::Any.new("claude-sonnet-4-6")},
        ),
      ]

      batch_req = Anthropic::CreateMessageBatchRequest.new(requests)
      json = batch_req.to_json
      json.should contain("\"custom_id\":\"req_1\"")
    end

    it "raises on empty requests" do
      expect_raises(ArgumentError, "requests must not be empty") do
        Anthropic::CreateMessageBatchRequest.new([] of Anthropic::CreateMessageBatchRequest::BatchRequest)
      end
    end
  end

  describe "BatchRequest typed constructor" do
    it "creates a BatchRequest from a typed Messages::Request" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello")],
        max_tokens: 1024
      )
      batch_req = Anthropic::CreateMessageBatchRequest::BatchRequest.new(
        custom_id: "req-1",
        request: request
      )

      batch_req.custom_id.should eq("req-1")
      batch_req.params["model"].as_s.should eq("claude-sonnet-4-6")
      batch_req.params["max_tokens"].as_i.should eq(1024)
      batch_req.params["messages"].as_a.size.should eq(1)
    end

    it "preserves optional fields from the request" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello")],
        max_tokens: 1024,
        system: "You are helpful.",
        temperature: 0.7,
        top_p: 0.9,
        top_k: 40,
        stop_sequences: ["STOP"]
      )
      batch_req = Anthropic::CreateMessageBatchRequest::BatchRequest.new(
        custom_id: "req-opts",
        request: request
      )

      batch_req.params["system"].as_s.should eq("You are helpful.")
      batch_req.params["temperature"].as_f.should eq(0.7)
      batch_req.params["top_p"].as_f.should eq(0.9)
      batch_req.params["top_k"].as_i.should eq(40)
      batch_req.params["stop_sequences"].as_a.size.should eq(1)
      batch_req.params["stop_sequences"].as_a[0].as_s.should eq("STOP")
    end

    it "omits nil optional fields" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello")],
        max_tokens: 512
      )
      batch_req = Anthropic::CreateMessageBatchRequest::BatchRequest.new(
        custom_id: "req-minimal",
        request: request
      )

      batch_req.params.has_key?("system").should be_false
      batch_req.params.has_key?("temperature").should be_false
      batch_req.params.has_key?("top_p").should be_false
      batch_req.params.has_key?("top_k").should be_false
      batch_req.params.has_key?("stop_sequences").should be_false
      batch_req.params.has_key?("stream").should be_false
    end

    it "accepts a string model name" do
      request = Anthropic::Messages::Request.new(
        model: "claude-sonnet-4-6",
        messages: [Anthropic::Message.user("Hello")],
        max_tokens: 256
      )
      batch_req = Anthropic::CreateMessageBatchRequest::BatchRequest.new(
        custom_id: "req-string-model",
        request: request
      )

      batch_req.params["model"].as_s.should eq("claude-sonnet-4-6")
    end

    it "serializes to JSON correctly" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100
      )
      batch_req = Anthropic::CreateMessageBatchRequest::BatchRequest.new(
        custom_id: "req-json",
        request: request
      )

      json = batch_req.to_json
      parsed = JSON.parse(json)
      parsed["custom_id"].as_s.should eq("req-json")
      parsed["params"]["model"].as_s.should eq("claude-sonnet-4-6")
      parsed["params"]["max_tokens"].as_i.should eq(100)
      parsed["params"]["messages"].as_a.size.should eq(1)
    end
  end

  describe ".from_requests" do
    it "creates a batch from typed request tuples" do
      items = [
        {"req-1", Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hello")],
          max_tokens: 1024
        )},
        {"req-2", Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("World")],
          max_tokens: 512
        )},
      ]
      batch = Anthropic::CreateMessageBatchRequest.from_requests(items)

      json = batch.to_json
      json.should contain("req-1")
      json.should contain("req-2")
    end

    it "preserves each request's parameters" do
      items = [
        {"a", Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("First")],
          max_tokens: 100
        )},
        {"b", Anthropic::Messages::Request.new(
          model: "claude-haiku-3",
          messages: [Anthropic::Message.user("Second")],
          max_tokens: 200,
          temperature: 0.5
        )},
      ]
      batch = Anthropic::CreateMessageBatchRequest.from_requests(items)

      json = batch.to_json
      parsed = JSON.parse(json)
      requests = parsed["requests"].as_a

      requests.size.should eq(2)
      requests[0]["custom_id"].as_s.should eq("a")
      requests[0]["params"]["max_tokens"].as_i.should eq(100)

      requests[1]["custom_id"].as_s.should eq("b")
      requests[1]["params"]["model"].as_s.should eq("claude-haiku-3")
      requests[1]["params"]["max_tokens"].as_i.should eq(200)
      requests[1]["params"]["temperature"].as_f.should eq(0.5)
    end

    it "raises on empty batch items" do
      expect_raises(ArgumentError, "requests must not be empty") do
        Anthropic::CreateMessageBatchRequest.from_requests(
          [] of {String, Anthropic::Messages::Request}
        )
      end
    end
  end
end

describe Anthropic::Messages::BatchAPI do
  describe "#list" do
    it "returns paginated batches" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "batch_1", type: "message_batch", processing_status: "succeeded",
               request_counts: {processing: 0, succeeded: 5, errored: 0, canceled: 0, expired: 0},
               created_at: "2025-01-01T00:00:00Z"},
            ],
            has_more: false,
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      page = client.batches.list

      page.data.size.should eq(1)
      page.data[0].id.should eq("batch_1")
      page.has_more?.should be_false
    end
  end

  describe "#retrieve" do
    it "returns a specific batch" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_123")
        .to_return(
          status: 200,
          body: {
            id:                "batch_123",
            type:              "message_batch",
            processing_status: "succeeded",
            request_counts:    {processing: 0, succeeded: 10, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      batch = client.batches.retrieve("batch_123")

      batch.id.should eq("batch_123")
      batch.processing_status.should eq("succeeded")
    end

    it "encodes batch_id with slashes in path" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch%2Fwith%2Fslashes")
        .to_return(
          status: 200,
          body: {
            id:                "batch/with/slashes",
            type:              "message_batch",
            processing_status: "succeeded",
            request_counts:    {processing: 0, succeeded: 1, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      batch = client.batches.retrieve("batch/with/slashes")
      batch.id.should eq("batch/with/slashes")
    end

    it "encodes batch_id with query and fragment characters in path" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/id%3Fquery%23fragment")
        .to_return(
          status: 200,
          body: {
            id:                "id?query#fragment",
            type:              "message_batch",
            processing_status: "succeeded",
            request_counts:    {processing: 0, succeeded: 1, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      batch = client.batches.retrieve("id?query#fragment")
      batch.id.should eq("id?query#fragment")
    end
  end

  describe "#cancel" do
    it "cancels an in-progress batch" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages/batches/batch_123/cancel")
        .to_return(
          status: 200,
          body: {
            id:                "batch_123",
            type:              "message_batch",
            processing_status: "cancelling",
            request_counts:    {processing: 5, succeeded: 3, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      batch = client.batches.cancel("batch_123")

      batch.processing_status.should eq("cancelling")
    end

    it "encodes batch_id with reserved characters in cancel path" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages/batches/batch%2Fwith%2Fslashes/cancel")
        .to_return(
          status: 200,
          body: {
            id:                "batch/with/slashes",
            type:              "message_batch",
            processing_status: "cancelling",
            request_counts:    {processing: 3, succeeded: 0, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      batch = client.batches.cancel("batch/with/slashes")
      batch.processing_status.should eq("cancelling")
    end
  end

  describe "#delete" do
    it "sends DELETE to /v1/messages/batches/{id}" do
      WebMock.stub(:delete, "https://api.anthropic.com/v1/messages/batches/batch_123")
        .to_return(
          status: 200,
          body: {
            id:   "batch_123",
            type: "message_batch_deleted",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      deleted = client.batches.delete("batch_123")

      deleted.id.should eq("batch_123")
      deleted.type.should eq("message_batch_deleted")
    end

    it "returns a MessageBatchDeleted struct" do
      WebMock.stub(:delete, "https://api.anthropic.com/v1/messages/batches/batch_456")
        .to_return(
          status: 200,
          body: {
            id:   "batch_456",
            type: "message_batch_deleted",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      deleted = client.batches.delete("batch_456")

      deleted.should be_a(Anthropic::MessageBatchDeleted)
      deleted.id.should eq("batch_456")
    end

    it "encodes batch_id with reserved characters in delete path" do
      WebMock.stub(:delete, "https://api.anthropic.com/v1/messages/batches/batch%2Fwith%2Fslashes")
        .to_return(
          status: 200,
          body: {
            id:   "batch/with/slashes",
            type: "message_batch_deleted",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      deleted = client.batches.delete("batch/with/slashes")
      deleted.id.should eq("batch/with/slashes")
    end
  end

  describe "#results" do
    it "raises BatchResultsNotReadyError when results_url is nil" do
      # Batch without results_url (not yet complete)
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_in_progress")
        .to_return(
          status: 200,
          body: {
            id:                "batch_in_progress",
            type:              "message_batch",
            processing_status: "in_progress",
            request_counts:    {processing: 5, succeeded: 0, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
            # results_url is nil
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      error = expect_raises(Anthropic::BatchResultsNotReadyError) do
        client.batches.results("batch_in_progress") { |_| }
      end
      error.batch_id.should eq("batch_in_progress")
      error.processing_status.should eq("in_progress")
      if msg = error.message
        msg.should contain("results are not available")
      else
        fail "Expected error message to be present"
      end
    end

    it "handles relative results_url" do
      ndjson = <<-JSON
        {"custom_id":"req_1","result":{"type":"succeeded","message":{"id":"msg_1","type":"message","role":"assistant","content":[{"type":"text","text":"Hello!"}],"model":"claude-sonnet-4-20250514","stop_reason":"end_turn","usage":{"input_tokens":10,"output_tokens":5}}}}
        JSON

      # Batch with relative results_url
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_relative")
        .to_return(
          status: 200,
          body: {
            id:                "batch_relative",
            type:              "message_batch",
            processing_status: "ended",
            request_counts:    {processing: 0, succeeded: 1, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
            results_url:       "/v1/messages/batches/batch_relative/results",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      # Results endpoint
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_relative/results")
        .to_return(
          status: 200,
          body_io: IO::Memory.new(ndjson),
          headers: {"Content-Type" => "application/x-ndjson"},
        )

      client = TestHelpers.test_client
      results = [] of Anthropic::MessageBatchResult
      client.batches.results("batch_relative") { |result| results << result }

      results.size.should eq(1)
      results[0].custom_id.should eq("req_1")
    end

    it "handles absolute results_url" do
      ndjson = <<-JSON
        {"custom_id":"req_2","result":{"type":"succeeded","message":{"id":"msg_2","type":"message","role":"assistant","content":[{"type":"text","text":"World!"}],"model":"claude-sonnet-4-20250514","stop_reason":"end_turn","usage":{"input_tokens":8,"output_tokens":3}}}}
        JSON

      # Batch with absolute results_url
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_absolute")
        .to_return(
          status: 200,
          body: {
            id:                "batch_absolute",
            type:              "message_batch",
            processing_status: "ended",
            request_counts:    {processing: 0, succeeded: 1, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
            results_url:       "https://api.anthropic.com/v1/messages/batches/batch_absolute/results",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      # Results endpoint - note: client.get uses base_url + path, so it requests the full URL
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_absolute/results")
        .to_return(
          status: 200,
          body_io: IO::Memory.new(ndjson),
          headers: {"Content-Type" => "application/x-ndjson"},
        )

      client = TestHelpers.test_client
      results = [] of Anthropic::MessageBatchResult
      client.batches.results("batch_absolute") { |result| results << result }

      results.size.should eq(1)
      results[0].custom_id.should eq("req_2")
    end

    it "streams NDJSON results line by line" do
      # Multi-line NDJSON to verify streaming behavior
      ndjson = <<-JSON
        {"custom_id":"req_1","result":{"type":"succeeded","message":{"id":"msg_1","type":"message","role":"assistant","content":[{"type":"text","text":"First"}],"model":"claude-sonnet-4-20250514","stop_reason":"end_turn","usage":{"input_tokens":5,"output_tokens":2}}}}
        {"custom_id":"req_2","result":{"type":"succeeded","message":{"id":"msg_2","type":"message","role":"assistant","content":[{"type":"text","text":"Second"}],"model":"claude-sonnet-4-20250514","stop_reason":"end_turn","usage":{"input_tokens":5,"output_tokens":2}}}}
        {"custom_id":"req_3","result":{"type":"succeeded","message":{"id":"msg_3","type":"message","role":"assistant","content":[{"type":"text","text":"Third"}],"model":"claude-sonnet-4-20250514","stop_reason":"end_turn","usage":{"input_tokens":5,"output_tokens":2}}}}
        JSON

      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_streaming")
        .to_return(
          status: 200,
          body: {
            id:                "batch_streaming",
            type:              "message_batch",
            processing_status: "ended",
            request_counts:    {processing: 0, succeeded: 3, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
            results_url:       "/v1/messages/batches/batch_streaming/results",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_streaming/results")
        .to_return(
          status: 200,
          body_io: IO::Memory.new(ndjson),
          headers: {"Content-Type" => "application/x-ndjson"},
        )

      client = TestHelpers.test_client
      results = [] of Anthropic::MessageBatchResult
      client.batches.results("batch_streaming") { |result| results << result }

      results.size.should eq(3)
      results[0].custom_id.should eq("req_1")
      results[1].custom_id.should eq("req_2")
      results[2].custom_id.should eq("req_3")
    end

    it "raises URLAuthorityMismatchError when results_url authority differs from client base_url" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_malicious")
        .to_return(
          status: 200,
          body: {
            id:                "batch_malicious",
            type:              "message_batch",
            processing_status: "ended",
            request_counts:    {processing: 0, succeeded: 1, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
            # Malicious URL pointing to different host
            results_url: "https://evil.com/v1/messages/batches/stolen/results",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      error = expect_raises(Anthropic::URLAuthorityMismatchError) do
        client.batches.results("batch_malicious") { |_| }
      end
      error.expected_authority.should eq("https://api.anthropic.com")
      error.actual_authority.should eq("https://evil.com")
      if msg = error.message
        msg.should contain("evil.com")
        msg.should contain("api.anthropic.com")
        msg.should contain("does not match")
      else
        fail "Expected error message to be present"
      end
    end

    it "raises URLAuthorityMismatchError on scheme downgrade (http vs https)" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_scheme")
        .to_return(
          status: 200,
          body: {
            id:                "batch_scheme",
            type:              "message_batch",
            processing_status: "ended",
            request_counts:    {processing: 0, succeeded: 1, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
            # Scheme downgrade: http instead of https
            results_url: "http://api.anthropic.com/v1/messages/batches/batch_scheme/results",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      error = expect_raises(Anthropic::URLAuthorityMismatchError) do
        client.batches.results("batch_scheme") { |_| }
      end
      error.expected_authority.should eq("https://api.anthropic.com")
      error.actual_authority.should eq("http://api.anthropic.com")
      if msg = error.message
        msg.should contain("does not match")
      else
        fail "Expected error message to be present"
      end
    end

    it "raises URLAuthorityMismatchError on port mismatch" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_port")
        .to_return(
          status: 200,
          body: {
            id:                "batch_port",
            type:              "message_batch",
            processing_status: "ended",
            request_counts:    {processing: 0, succeeded: 1, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
            # Port mismatch: non-default port 8443
            results_url: "https://api.anthropic.com:8443/v1/messages/batches/batch_port/results",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      error = expect_raises(Anthropic::URLAuthorityMismatchError) do
        client.batches.results("batch_port") { |_| }
      end
      error.expected_authority.should eq("https://api.anthropic.com")
      error.actual_authority.should eq("https://api.anthropic.com:8443")
      if msg = error.message
        msg.should contain("does not match")
      else
        fail "Expected error message to be present"
      end
    end

    it "raises MalformedResultsURLError for protocol-relative results_url" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_proto_rel")
        .to_return(
          status: 200,
          body: {
            id:                "batch_proto_rel",
            type:              "message_batch",
            processing_status: "ended",
            request_counts:    {processing: 0, succeeded: 1, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
            results_url:       "//evil.com/v1/messages/batches/stolen/results",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      error = expect_raises(Anthropic::MalformedResultsURLError) do
        client.batches.results("batch_proto_rel") { |_| }
      end
      error.url.should eq("//evil.com/v1/messages/batches/stolen/results")
      if msg = error.message
        msg.should contain("protocol-relative")
      else
        fail "Expected error message to be present"
      end
    end

    it "raises MalformedResultsURLError for non-path relative results_url" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_nopath")
        .to_return(
          status: 200,
          body: {
            id:                "batch_nopath",
            type:              "message_batch",
            processing_status: "ended",
            request_counts:    {processing: 0, succeeded: 1, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
            results_url:       "foo/bar/results",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      error = expect_raises(Anthropic::MalformedResultsURLError) do
        client.batches.results("batch_nopath") { |_| }
      end
      error.url.should eq("foo/bar/results")
      if msg = error.message
        msg.should contain("absolute path")
      else
        fail "Expected error message to be present"
      end
    end

    it "is also accessible as URLHostMismatchError (backward compat alias)" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_alias")
        .to_return(
          status: 200,
          body: {
            id:                "batch_alias",
            type:              "message_batch",
            processing_status: "ended",
            request_counts:    {processing: 0, succeeded: 1, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
            results_url:       "https://evil.com/v1/messages/batches/batch_alias/results",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      expect_raises(Anthropic::URLHostMismatchError) do
        client.batches.results("batch_alias") { |_| }
      end
    end

    it "forwards request_options to both retrieve and results fetch" do
      ndjson = <<-JSON
        {"custom_id":"req_opts","result":{"type":"succeeded","message":{"id":"msg_opts","type":"message","role":"assistant","content":[{"type":"text","text":"OK"}],"model":"claude-sonnet-4-20250514","stop_reason":"end_turn","usage":{"input_tokens":5,"output_tokens":2}}}}
        JSON

      # Stub both endpoints with expected headers - stubs match only when headers present
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_opts")
        .with(headers: {"anthropic-beta" => "test-beta", "X-Custom" => "value"})
        .to_return(
          status: 200,
          body: {
            id:                "batch_opts",
            type:              "message_batch",
            processing_status: "ended",
            request_counts:    {processing: 0, succeeded: 1, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
            results_url:       "/v1/messages/batches/batch_opts/results",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_opts/results")
        .with(headers: {"anthropic-beta" => "test-beta", "X-Custom" => "value"})
        .to_return(
          status: 200,
          body_io: IO::Memory.new(ndjson),
          headers: {"Content-Type" => "application/x-ndjson"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        timeout: 30.seconds,
        beta_headers: ["test-beta"],
        extra_headers: HTTP::Headers{"X-Custom" => ["value"]}
      )

      results = [] of Anthropic::MessageBatchResult
      client.batches.results("batch_opts", options) { |result| results << result }

      # If headers weren't forwarded, the stubs wouldn't match and this would fail
      results.size.should eq(1)
      results[0].custom_id.should eq("req_opts")
    end
  end

  describe "#create with request_options" do
    it "forwards request_options to client" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages/batches")
        .with(headers: {"anthropic-beta" => "batch-beta"})
        .to_return(
          status: 200,
          body: {
            id:                "batch_new",
            type:              "message_batch",
            processing_status: "in_progress",
            request_counts:    {processing: 1, succeeded: 0, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        timeout: 60.seconds,
        beta_headers: ["batch-beta"]
      )

      requests = [
        Anthropic::CreateMessageBatchRequest::BatchRequest.new(
          custom_id: "req_1",
          params: {"model" => JSON::Any.new("claude-sonnet-4-6")},
        ),
      ]

      batch = client.batches.create(requests, options)
      batch.id.should eq("batch_new")
    end
  end

  describe "#list with request_options" do
    it "forwards request_options to client" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches?limit=10")
        .to_return(
          status: 200,
          body: {
            data:     [] of String,
            has_more: false,
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(timeout: 30.seconds)
      params = Anthropic::ListParams.new(limit: 10)

      page = client.batches.list(params, options)
      page.data.size.should eq(0)
    end
  end

  describe "#retrieve with request_options" do
    it "forwards request_options to client" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_retrieve")
        .with(headers: {"X-Request-Id" => "custom-123"})
        .to_return(
          status: 200,
          body: {
            id:                "batch_retrieve",
            type:              "message_batch",
            processing_status: "succeeded",
            request_counts:    {processing: 0, succeeded: 5, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Request-Id" => ["custom-123"]}
      )

      batch = client.batches.retrieve("batch_retrieve", options)
      batch.id.should eq("batch_retrieve")
    end
  end

  describe "#cancel with request_options" do
    it "forwards request_options to client" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages/batches/batch_cancel/cancel")
        .to_return(
          status: 200,
          body: {
            id:                "batch_cancel",
            type:              "message_batch",
            processing_status: "cancelling",
            request_counts:    {processing: 3, succeeded: 2, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(timeout: 15.seconds)

      batch = client.batches.cancel("batch_cancel", options)
      batch.processing_status.should eq("cancelling")
    end
  end

  describe "#delete with request_options" do
    it "forwards request_options to client" do
      WebMock.stub(:delete, "https://api.anthropic.com/v1/messages/batches/batch_del")
        .to_return(
          status: 200,
          body: {
            id:   "batch_del",
            type: "message_batch_deleted",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(timeout: 10.seconds)

      deleted = client.batches.delete("batch_del", options)
      deleted.id.should eq("batch_del")
    end
  end

  describe "#list_all with request_options" do
    it "forwards request_options through pagination" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches")
        .with(headers: {"anthropic-beta" => "list-beta"})
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "batch_1", type: "message_batch", processing_status: "succeeded",
               request_counts: {processing: 0, succeeded: 5, errored: 0, canceled: 0, expired: 0},
               created_at: "2025-01-01T00:00:00Z"},
            ],
            has_more: false,
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        beta_headers: ["list-beta"]
      )

      batches = client.batches.list_all(request_options: options).to_a
      batches.size.should eq(1)
      batches[0].id.should eq("batch_1")
    end
  end
end

describe Anthropic::BatchResultMessage do
  describe "JSON deserialization" do
    it "parses a full response-shaped message" do
      json = <<-JSON
        {
          "id": "msg_batch_123",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "text", "text": "Hello from batch!"}
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "end_turn",
          "stop_sequence": null,
          "usage": {"input_tokens": 15, "output_tokens": 10}
        }
        JSON

      msg = Anthropic::BatchResultMessage.from_json(json)
      msg.id.should eq("msg_batch_123")
      msg.type.should eq("message")
      msg.role.should eq("assistant")
      msg.model.should eq("claude-sonnet-4-20250514")
      msg.stop_reason.should eq("end_turn")
      msg.stop_sequence.should be_nil
      msg.usage.input_tokens.should eq(15)
      msg.usage.output_tokens.should eq(10)
    end

    it "parses content with multiple block types" do
      json = <<-JSON
        {
          "id": "msg_mixed",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "thinking", "thinking": "Let me think...", "signature": "abc123"},
            {"type": "text", "text": "The answer is 42."},
            {"type": "tool_use", "id": "tool_1", "name": "calculator", "input": {"expr": "6*7"}}
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 20, "output_tokens": 50}
        }
        JSON

      msg = Anthropic::BatchResultMessage.from_json(json)
      msg.content.size.should eq(3)

      # Check thinking block
      if thinking = msg.content[0].as?(Anthropic::ResponseThinkingBlock)
        thinking.thinking.should eq("Let me think...")
        thinking.signature.should eq("abc123")
      else
        fail "Expected ResponseThinkingBlock"
      end

      # Check text block
      if text = msg.content[1].as?(Anthropic::ResponseTextBlock)
        text.text.should eq("The answer is 42.")
      else
        fail "Expected ResponseTextBlock"
      end

      # Check tool_use block
      if tool = msg.content[2].as?(Anthropic::ResponseToolUseBlock)
        tool.id.should eq("tool_1")
        tool.name.should eq("calculator")
      else
        fail "Expected ResponseToolUseBlock"
      end
    end

    it "handles unknown content block types" do
      json = <<-JSON
        {
          "id": "msg_unknown",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "future_block", "data": "some value"}
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 5, "output_tokens": 5}
        }
        JSON

      msg = Anthropic::BatchResultMessage.from_json(json)
      msg.content.size.should eq(1)

      unknown = msg.content[0].as?(Anthropic::ResponseUnknownBlock)
      if u = unknown
        u.type.should eq("future_block")
        u.raw["data"].as_s.should eq("some value")
      else
        fail "Expected ResponseUnknownBlock"
      end
    end

    it "handles null stop_reason and stop_sequence" do
      json = <<-JSON
        {
          "id": "msg_nulls",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "text", "text": "Hi"}],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": null,
          "stop_sequence": null,
          "usage": {"input_tokens": 5, "output_tokens": 2}
        }
        JSON

      msg = Anthropic::BatchResultMessage.from_json(json)
      msg.stop_reason.should be_nil
      msg.stop_sequence.should be_nil
    end
  end

  describe "#text" do
    it "extracts text from content blocks" do
      json = <<-JSON
        {
          "id": "msg_text",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "text", "text": "Hello "},
            {"type": "text", "text": "World!"}
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 5, "output_tokens": 10}
        }
        JSON

      msg = Anthropic::BatchResultMessage.from_json(json)
      msg.text.should eq("Hello World!")
    end
  end

  describe "#tool_use_blocks" do
    it "returns only tool use blocks" do
      json = <<-JSON
        {
          "id": "msg_tools",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "text", "text": "Let me help."},
            {"type": "tool_use", "id": "tool_1", "name": "search", "input": {"q": "test"}},
            {"type": "tool_use", "id": "tool_2", "name": "fetch", "input": {"id": 123}}
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 30}
        }
        JSON

      msg = Anthropic::BatchResultMessage.from_json(json)
      tools = msg.tool_use_blocks
      tools.size.should eq(2)
      tools[0].name.should eq("search")
      tools[1].name.should eq("fetch")
    end
  end

  describe "required field validation" do
    it "raises on missing id field" do
      json = %({"type": "message", "role": "assistant", "content": [], "model": "claude-sonnet-4-20250514", "stop_reason": "end_turn", "usage": {"input_tokens": 10, "output_tokens": 5}})
      expect_raises(JSON::ParseException, /Missing required field 'id'/) do
        Anthropic::BatchResultMessage.from_json(json)
      end
    end

    it "raises on missing type field" do
      json = %({"id": "msg_1", "role": "assistant", "content": [], "model": "claude-sonnet-4-20250514", "stop_reason": "end_turn", "usage": {"input_tokens": 10, "output_tokens": 5}})
      expect_raises(JSON::ParseException, /Missing required field 'type'/) do
        Anthropic::BatchResultMessage.from_json(json)
      end
    end

    it "raises on missing role field" do
      json = %({"id": "msg_1", "type": "message", "content": [], "model": "claude-sonnet-4-20250514", "stop_reason": "end_turn", "usage": {"input_tokens": 10, "output_tokens": 5}})
      expect_raises(JSON::ParseException, /Missing required field 'role'/) do
        Anthropic::BatchResultMessage.from_json(json)
      end
    end

    it "raises on missing model field" do
      json = %({"id": "msg_1", "type": "message", "role": "assistant", "content": [], "stop_reason": "end_turn", "usage": {"input_tokens": 10, "output_tokens": 5}})
      expect_raises(JSON::ParseException, /Missing required field 'model'/) do
        Anthropic::BatchResultMessage.from_json(json)
      end
    end

    it "raises on missing usage field" do
      json = %({"id": "msg_1", "type": "message", "role": "assistant", "content": [], "model": "claude-sonnet-4-20250514", "stop_reason": "end_turn"})
      expect_raises(JSON::ParseException, /Missing required field 'usage'/) do
        Anthropic::BatchResultMessage.from_json(json)
      end
    end

    it "allows missing optional fields (stop_reason, stop_sequence, content)" do
      json = %({"id": "msg_1", "type": "message", "role": "assistant", "model": "claude-sonnet-4-20250514", "usage": {"input_tokens": 10, "output_tokens": 5}})
      msg = Anthropic::BatchResultMessage.from_json(json)
      msg.id.should eq("msg_1")
      msg.content.should be_empty
      msg.stop_reason.should be_nil
      msg.stop_sequence.should be_nil
    end
  end
end

describe Anthropic::MessageBatchResult do
  describe "JSON deserialization" do
    it "parses a succeeded result with message" do
      json = <<-JSON
        {
          "custom_id": "req_123",
          "result": {
            "type": "succeeded",
            "message": {
              "id": "msg_123",
              "type": "message",
              "role": "assistant",
              "content": [{"type": "text", "text": "Success response"}],
              "model": "claude-sonnet-4-20250514",
              "stop_reason": "end_turn",
              "usage": {"input_tokens": 10, "output_tokens": 20}
            }
          }
        }
        JSON

      result = Anthropic::MessageBatchResult.from_json(json)
      result.custom_id.should eq("req_123")
      result.result.type.should eq("succeeded")

      if msg = result.result.message
        msg.id.should eq("msg_123")
        msg.text.should eq("Success response")
        msg.model.should eq("claude-sonnet-4-20250514")
        msg.stop_reason.should eq("end_turn")
      else
        fail "Expected message to be present"
      end

      result.result.error.should be_nil
    end

    it "parses an errored result with error info" do
      json = <<-JSON
        {
          "custom_id": "req_456",
          "result": {
            "type": "errored",
            "error": {
              "type": "invalid_request_error",
              "message": "Model not found"
            }
          }
        }
        JSON

      result = Anthropic::MessageBatchResult.from_json(json)
      result.custom_id.should eq("req_456")
      result.result.type.should eq("errored")
      result.result.message.should be_nil

      if error = result.result.error
        error.type.should eq("invalid_request_error")
        error.message.should eq("Model not found")
      else
        fail "Expected error to be present"
      end
    end

    it "parses a cancelled result" do
      json = <<-JSON
        {
          "custom_id": "req_789",
          "result": {
            "type": "cancelled"
          }
        }
        JSON

      result = Anthropic::MessageBatchResult.from_json(json)
      result.custom_id.should eq("req_789")
      result.result.type.should eq("cancelled")
      result.result.message.should be_nil
      result.result.error.should be_nil
    end
  end
end

describe Anthropic::BatchResultsNotReadyError do
  it "includes batch_id and processing_status" do
    error = Anthropic::BatchResultsNotReadyError.new("batch_123", "in_progress")
    error.batch_id.should eq("batch_123")
    error.processing_status.should eq("in_progress")
    if msg = error.message
      msg.should contain("batch_123")
      msg.should contain("in_progress")
      msg.should contain("results are not available")
    else
      fail "Expected error message to be present"
    end
  end
end

describe Anthropic::URLAuthorityMismatchError do
  it "includes expected and actual authority" do
    error = Anthropic::URLAuthorityMismatchError.new("https://api.anthropic.com", "https://evil.com")
    error.expected_authority.should eq("https://api.anthropic.com")
    error.actual_authority.should eq("https://evil.com")
    if msg = error.message
      msg.should contain("evil.com")
      msg.should contain("api.anthropic.com")
      msg.should contain("does not match")
      msg.should contain("unauthorized origin")
    else
      fail "Expected error message to be present"
    end
  end

  it "is aliased as URLHostMismatchError for backward compatibility" do
    error = Anthropic::URLHostMismatchError.new("https://api.anthropic.com", "https://evil.com")
    error.should be_a(Anthropic::URLAuthorityMismatchError)
    error.expected_authority.should eq("https://api.anthropic.com")
    error.actual_authority.should eq("https://evil.com")
  end
end

describe Anthropic::MalformedResultsURLError do
  it "includes url and reason in message" do
    error = Anthropic::MalformedResultsURLError.new("//evil.com/path", "protocol-relative URLs are not allowed")
    error.url.should eq("//evil.com/path")
    if msg = error.message
      msg.should contain("//evil.com/path")
      msg.should contain("protocol-relative")
    else
      fail "Expected error message to be present"
    end
  end
end
