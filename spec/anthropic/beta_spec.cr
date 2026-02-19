require "../spec_helper"

describe Anthropic::Beta::API do
  describe "#skills" do
    it "provides access to skills API" do
      body = <<-JSON
        {
          "data": [
            {
              "id": "skill_01ABC123",
              "type": "skill",
              "display_title": "PDF Reader",
              "source": "anthropic",
              "latest_version": "1759178010641129",
              "created_at": "2025-01-15T12:00:00Z",
              "updated_at": "2025-01-15T12:00:00Z"
            }
          ],
          "has_more": false
        }
        JSON

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills")
        .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      response = client.beta.skills.list

      response.data.size.should eq(1)

      if skill = response.data.first?
        skill.id.should eq("skill_01ABC123")
        skill.display_title.should eq("PDF Reader")
      end
    end

    it "includes beta header in skills requests" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/skills")
        .with(headers: {"anthropic-beta" => "skills-2025-10-02"})
        .to_return(status: 200, body: %({"data": [], "has_more": false}), headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      client.beta.skills.list
    end
  end

  describe "#options" do
    it "creates request options with beta headers" do
      client = TestHelpers.test_client
      beta_api = client.beta(["feature-2025-01-01"])

      options = beta_api.options
      options.beta_headers.should eq(["feature-2025-01-01"])
    end

    it "merges additional beta headers" do
      client = TestHelpers.test_client
      beta_api = client.beta(["base-feature"])

      options = beta_api.options(["additional-feature"])
      if betas = options.beta_headers
        betas.should contain("base-feature")
        betas.should contain("additional-feature")
      end
    end

    it "deduplicates beta headers" do
      client = TestHelpers.test_client
      beta_api = client.beta(["feature-x"])

      options = beta_api.options(["feature-x", "feature-y"])
      if betas = options.beta_headers
        betas.count("feature-x").should eq(1)
      end
    end

    it "returns empty array when no beta headers configured" do
      client = TestHelpers.test_client
      beta_api = client.beta

      options = beta_api.options
      if betas = options.beta_headers
        betas.should be_empty
      end
    end
  end

  describe "#merge_options" do
    it "merges beta headers into existing options" do
      client = TestHelpers.test_client
      beta_api = client.beta(["beta-feature"])

      base_options = Anthropic::RequestOptions.new(timeout: 30.seconds)
      merged = beta_api.merge_options(base_options)

      merged.timeout.should eq(30.seconds)
      if betas = merged.beta_headers
        betas.should contain("beta-feature")
      end
    end

    it "preserves existing beta headers" do
      client = TestHelpers.test_client
      beta_api = client.beta(["namespace-beta"])

      base_options = Anthropic::RequestOptions.new(beta_headers: ["existing-beta"])
      merged = beta_api.merge_options(base_options)

      if betas = merged.beta_headers
        betas.should contain("namespace-beta")
        betas.should contain("existing-beta")
      end
    end

    it "handles nil options" do
      client = TestHelpers.test_client
      beta_api = client.beta(["test-beta"])

      merged = beta_api.merge_options(nil)

      if betas = merged.beta_headers
        betas.should eq(["test-beta"])
      end
    end

    it "preserves extra_body from input options" do
      client = TestHelpers.test_client
      beta_api = client.beta(["test-beta"])

      extra_body = {"custom_field" => JSON::Any.new("custom_value")}
      base_options = Anthropic::RequestOptions.new(extra_body: extra_body)
      merged = beta_api.merge_options(base_options)

      if body = merged.extra_body
        body["custom_field"].should eq(JSON::Any.new("custom_value"))
      end
    end

    it "preserves extra_query from input options" do
      client = TestHelpers.test_client
      beta_api = client.beta(["test-beta"])

      extra_query = {"debug" => "true", "version" => "2"}
      base_options = Anthropic::RequestOptions.new(extra_query: extra_query)
      merged = beta_api.merge_options(base_options)

      if query = merged.extra_query
        query["debug"].should eq("true")
        query["version"].should eq("2")
      end
    end

    it "preserves both extra_body and extra_query together with beta headers" do
      client = TestHelpers.test_client
      beta_api = client.beta(["namespace-beta"])

      extra_body = {"priority" => JSON::Any.new("high")}
      extra_query = {"include" => "metadata"}
      base_options = Anthropic::RequestOptions.new(
        timeout: 45.seconds,
        beta_headers: ["existing-beta"],
        extra_body: extra_body,
        extra_query: extra_query,
      )
      merged = beta_api.merge_options(base_options)

      merged.timeout.should eq(45.seconds)
      if betas = merged.beta_headers
        betas.should contain("namespace-beta")
        betas.should contain("existing-beta")
      end
      if body = merged.extra_body
        body["priority"].should eq(JSON::Any.new("high"))
      end
      if query = merged.extra_query
        query["include"].should eq("metadata")
      end
    end
  end

  describe "defensive copies" do
    it "does not mutate stored beta_headers when original array is modified" do
      client = TestHelpers.test_client
      original = ["feature-a", "feature-b"]
      beta_api = Anthropic::Beta::API.new(client, beta_headers: original)

      original << "injected-header"

      beta_api.beta_headers.should eq(["feature-a", "feature-b"])
      beta_api.beta_headers.size.should eq(2)
    end

    it "does not leak internal beta_headers via getter" do
      client = TestHelpers.test_client
      beta_api = Anthropic::Beta::API.new(client, ["original"])
      beta_api.beta_headers << "injected"
      beta_api.beta_headers.should eq(["original"])
    end
  end

  describe "client.beta accessor" do
    it "creates beta API with default headers" do
      client = TestHelpers.test_client
      beta_api = client.beta

      beta_api.client.should be(client)
      beta_api.beta_headers.should be_empty
    end

    it "creates beta API with custom headers" do
      client = TestHelpers.test_client
      beta_api = client.beta(["custom-beta-2025"])

      beta_api.beta_headers.should eq(["custom-beta-2025"])
    end
  end

  describe "beta header propagation" do
    it "includes beta headers in actual requests via client.post" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/test")
        .with(headers: {"anthropic-beta" => "test-beta-header"})
        .to_return(
          status: 200,
          body: %({"success": true}),
          headers: {"Content-Type" => "application/json"}
        )

      client = TestHelpers.test_client
      beta_api = client.beta(["test-beta-header"])

      response = client.post("/v1/test", "{}", options: beta_api.options)
      response.status_code.should eq(200)
    end
  end

  describe "beta namespace header propagation through skills" do
    it "merges namespace beta headers with skills beta header in list" do
      captured_headers = HTTP::Headers.new

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills")
        .to_return do |request|
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: %({"data": [], "has_more": false}),
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.beta(["custom-feature-2025"]).skills.list

      if beta_header = captured_headers["anthropic-beta"]?
        beta_header.should contain("skills-2025-10-02")
        beta_header.should contain("custom-feature-2025")
      else
        fail "Expected anthropic-beta header to be present"
      end
    end

    it "merges namespace beta headers with skills beta header in retrieve" do
      captured_headers = HTTP::Headers.new

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills/skill_01ABC123")
        .to_return do |request|
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: <<-JSON,
              {
                "id": "skill_01ABC123", "type": "skill", "display_title": "Test",
                "source": "custom", "latest_version": "123", "created_at": "2025-01-15T12:00:00Z",
                "updated_at": "2025-01-15T12:00:00Z"
              }
              JSON
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.beta(["extra-beta-2025"]).skills.retrieve("skill_01ABC123")

      if beta_header = captured_headers["anthropic-beta"]?
        beta_header.should contain("skills-2025-10-02")
        beta_header.should contain("extra-beta-2025")
      else
        fail "Expected anthropic-beta header to be present"
      end
    end

    it "merges multiple namespace headers with skills beta header" do
      captured_headers = HTTP::Headers.new

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills")
        .to_return do |request|
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: %({"data": [], "has_more": false}),
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.beta(["feature-a", "feature-b"]).skills.list

      if beta_header = captured_headers["anthropic-beta"]?
        beta_header.should contain("skills-2025-10-02")
        beta_header.should contain("feature-a")
        beta_header.should contain("feature-b")
      else
        fail "Expected anthropic-beta header to be present"
      end
    end

    it "deduplicates when namespace includes skills beta header" do
      captured_headers = HTTP::Headers.new

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills")
        .to_return do |request|
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: %({"data": [], "has_more": false}),
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      # Pass the skills beta header as a namespace header too - should be deduplicated
      client.beta(["skills-2025-10-02", "extra-feature"]).skills.list

      if beta_header = captured_headers["anthropic-beta"]?
        # Should contain each only once
        parts = beta_header.split(",")
        parts.count("skills-2025-10-02").should eq(1)
        parts.should contain("extra-feature")
      else
        fail "Expected anthropic-beta header to be present"
      end
    end

    it "merges namespace headers with per-request options for skills" do
      captured_headers = HTTP::Headers.new

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills")
        .to_return do |request|
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: %({"data": [], "has_more": false}),
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      request_opts = Anthropic::RequestOptions.new(beta_headers: ["request-level-beta"])
      client.beta(["namespace-beta"]).skills.list(request_options: request_opts)

      if beta_header = captured_headers["anthropic-beta"]?
        beta_header.should contain("skills-2025-10-02")
        beta_header.should contain("namespace-beta")
        beta_header.should contain("request-level-beta")
      else
        fail "Expected anthropic-beta header to be present"
      end
    end
  end

  describe "#files" do
    file_response_json = {
      id:         "file_beta1",
      type:       "file",
      filename:   "beta-doc.txt",
      size_bytes: 42,
      created_at: "2025-01-01T00:00:00Z",
    }.to_json

    describe "upload" do
      it "merges beta headers into upload request" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:post, "https://api.anthropic.com/v1/files")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: file_response_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        client.beta(["files-beta-2025"]).files.upload("doc.txt", "content")

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("files-beta-2025")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end

      it "preserves multipart Content-Type for uploads" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:post, "https://api.anthropic.com/v1/files")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: file_response_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        req = Anthropic::UploadFileRequest.from_string("test.txt", "hello", "text/plain")
        client.beta(["files-beta-2025"]).files.upload(req)

        if ct = captured_headers["Content-Type"]?
          ct.should contain("multipart/form-data; boundary=")
        else
          fail "Expected Content-Type header to be present"
        end
      end

      it "merges per-request beta headers with namespace headers for upload" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:post, "https://api.anthropic.com/v1/files")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: file_response_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        opts = Anthropic::RequestOptions.new(beta_headers: ["request-beta"])
        client.beta(["namespace-beta"]).files.upload("doc.txt", "content", request_options: opts)

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("namespace-beta")
          beta_header.should contain("request-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end

    describe "list" do
      it "merges beta headers into list request" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:get, "https://api.anthropic.com/v1/files")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: {data: [] of String, has_more: false}.to_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        client.beta(["files-list-beta"]).files.list

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("files-list-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end

    describe "retrieve" do
      it "merges beta headers into retrieve request" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_123")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: file_response_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        client.beta(["files-retrieve-beta"]).files.retrieve("file_123")

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("files-retrieve-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end

    describe "delete" do
      it "merges beta headers into delete request" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:delete, "https://api.anthropic.com/v1/files/file_123")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: {id: "file_123", type: "file_deleted"}.to_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        client.beta(["files-delete-beta"]).files.delete("file_123")

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("files-delete-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end

    describe "download" do
      it "merges beta headers into download request" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_dl/content")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: "file content bytes",
              headers: HTTP::Headers{"Content-Type" => "application/octet-stream"},
            )
          end

        client = TestHelpers.test_client
        data = client.beta(["files-download-beta"]).files.download("file_dl")

        data.should eq("file content bytes".to_slice)
        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("files-download-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end

      it "merges beta headers into download_string request" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_ds/content")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: "string content",
              headers: HTTP::Headers{"Content-Type" => "text/plain"},
            )
          end

        client = TestHelpers.test_client
        content = client.beta(["files-dlstr-beta"]).files.download_string("file_ds")

        content.should eq("string content")
        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("files-dlstr-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end

      it "merges beta headers into download_base64 request" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_b64/content")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: "base64 data",
              headers: HTTP::Headers{"Content-Type" => "application/octet-stream"},
            )
          end

        client = TestHelpers.test_client
        encoded = client.beta(["files-b64-beta"]).files.download_base64("file_b64")

        encoded.should eq(Base64.strict_encode("base64 data"))
        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("files-b64-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end

    describe "header deduplication" do
      it "deduplicates when namespace and per-request have the same beta header" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:get, "https://api.anthropic.com/v1/files")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: {data: [] of String, has_more: false}.to_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        opts = Anthropic::RequestOptions.new(beta_headers: ["shared-beta", "extra-beta"])
        client.beta(["shared-beta"]).files.list(request_options: opts)

        if beta_header = captured_headers["anthropic-beta"]?
          parts = beta_header.split(",")
          parts.count("shared-beta").should eq(1)
          parts.should contain("extra-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end

    describe "option preservation" do
      it "preserves timeout and extra_headers through merge" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_opts")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: file_response_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        opts = Anthropic::RequestOptions.new(
          timeout: 60.seconds,
          extra_headers: HTTP::Headers{"X-Custom" => "value"},
        )
        client.beta(["beta-header"]).files.retrieve("file_opts", opts)

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("beta-header")
        else
          fail "Expected anthropic-beta header to be present"
        end

        captured_headers["X-Custom"]?.should eq("value")
      end
    end
  end

  describe "#models" do
    it "provides access to models API" do
      body = <<-JSON
        {
          "data": [
            {
              "id": "claude-3-5-sonnet-20241022",
              "type": "model",
              "display_name": "Claude 3.5 Sonnet",
              "created_at": "2024-10-22T00:00:00Z"
            }
          ],
          "has_more": false
        }
        JSON

      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      response = client.beta.models.list

      response.data.size.should eq(1)

      if model = response.data.first?
        model.id.should eq("claude-3-5-sonnet-20241022")
        model.display_name.should eq("Claude 3.5 Sonnet")
      end
    end

    it "merges beta headers in models.list" do
      captured_headers = HTTP::Headers.new

      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return do |request|
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: %({"data": [], "has_more": false}),
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.beta(["custom-beta-2025"]).models.list

      if beta_header = captured_headers["anthropic-beta"]?
        beta_header.should contain("custom-beta-2025")
      else
        fail "Expected anthropic-beta header to be present"
      end
    end

    it "merges beta headers in models.retrieve" do
      captured_headers = HTTP::Headers.new

      WebMock.stub(:get, "https://api.anthropic.com/v1/models/claude-3-5-sonnet-20241022")
        .to_return do |request|
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: <<-JSON,
              {
                "id": "claude-3-5-sonnet-20241022",
                "type": "model",
                "display_name": "Claude 3.5 Sonnet",
                "created_at": "2024-10-22T00:00:00Z"
              }
              JSON
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.beta(["model-beta-2025"]).models.retrieve("claude-3-5-sonnet-20241022")

      if beta_header = captured_headers["anthropic-beta"]?
        beta_header.should contain("model-beta-2025")
      else
        fail "Expected anthropic-beta header to be present"
      end
    end

    it "merges multiple namespace headers in models.list" do
      captured_headers = HTTP::Headers.new

      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return do |request|
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: %({"data": [], "has_more": false}),
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.beta(["feature-a", "feature-b"]).models.list

      if beta_header = captured_headers["anthropic-beta"]?
        beta_header.should contain("feature-a")
        beta_header.should contain("feature-b")
      else
        fail "Expected anthropic-beta header to be present"
      end
    end

    it "preserves per-request options (timeout, extra_headers) in models.list" do
      captured_headers = HTTP::Headers.new

      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return do |request|
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: %({"data": [], "has_more": false}),
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      extra = HTTP::Headers.new
      extra["X-Custom-Header"] = "custom-value"
      request_opts = Anthropic::RequestOptions.new(
        timeout: 45.seconds,
        extra_headers: extra,
        beta_headers: ["request-level-beta"],
      )
      client.beta(["namespace-beta"]).models.list(request_options: request_opts)

      if beta_header = captured_headers["anthropic-beta"]?
        beta_header.should contain("namespace-beta")
        beta_header.should contain("request-level-beta")
      else
        fail "Expected anthropic-beta header to be present"
      end

      captured_headers["X-Custom-Header"]?.should eq("custom-value")
    end

    it "deduplicates beta headers when namespace includes same header" do
      captured_headers = HTTP::Headers.new

      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return do |request|
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: %({"data": [], "has_more": false}),
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      request_opts = Anthropic::RequestOptions.new(beta_headers: ["duplicate-beta"])
      client.beta(["duplicate-beta", "unique-beta"]).models.list(request_options: request_opts)

      if beta_header = captured_headers["anthropic-beta"]?
        parts = beta_header.split(",")
        parts.count("duplicate-beta").should eq(1)
        parts.should contain("unique-beta")
      else
        fail "Expected anthropic-beta header to be present"
      end
    end
  end

  describe "#messages" do
    it "provides access to messages namespace" do
      client = TestHelpers.test_client
      messages_api = client.beta.messages

      messages_api.should be_a(Anthropic::Beta::MessagesAPI)
    end

    it "provides access to batches through messages namespace" do
      client = TestHelpers.test_client
      batches_api = client.beta.messages.batches

      batches_api.should be_a(Anthropic::Beta::BatchesAPI)
    end

    describe "create" do
      it "merges beta headers in create request" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: TestHelpers.response_json(text: "Hello!"),
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        request = Anthropic::Messages::Request.new(
          Anthropic::Model.sonnet,
          [Anthropic::Message.user("Hi")],
          1024
        )
        client.beta(["beta-feature-2025"]).messages.create(request)

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("beta-feature-2025")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end

      it "merges beta headers in create with convenience overload" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: TestHelpers.response_json(text: "Response"),
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        client.beta(["convenience-beta"]).messages.create(
          Anthropic::Model.sonnet,
          [Anthropic::Message.user("Hello")],
          1024
        )

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("convenience-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end

      it "merges per-request beta headers with namespace beta headers" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: TestHelpers.response_json(text: "Response"),
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        request = Anthropic::Messages::Request.new(
          Anthropic::Model.sonnet,
          [Anthropic::Message.user("Hi")],
          1024
        )
        request_opts = Anthropic::RequestOptions.new(beta_headers: ["request-beta"])
        client.beta(["namespace-beta"]).messages.create(request, request_opts)

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("namespace-beta")
          beta_header.should contain("request-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end

      it "preserves per-request timeout and extra_headers" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: TestHelpers.response_json(text: "Response"),
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        request = Anthropic::Messages::Request.new(
          Anthropic::Model.sonnet,
          [Anthropic::Message.user("Hi")],
          1024
        )
        request_opts = Anthropic::RequestOptions.new(
          timeout: 45.seconds,
          beta_headers: ["request-beta"],
          extra_headers: HTTP::Headers{"X-Custom" => "custom-val"},
        )
        client.beta(["namespace-beta"]).messages.create(request, request_opts)

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("namespace-beta")
          beta_header.should contain("request-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end

        captured_headers["X-Custom"]?.should eq("custom-val")
      end

      it "deduplicates overlapping beta headers" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: TestHelpers.response_json(text: "Response"),
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        request = Anthropic::Messages::Request.new(
          Anthropic::Model.sonnet,
          [Anthropic::Message.user("Hi")],
          1024
        )
        request_opts = Anthropic::RequestOptions.new(beta_headers: ["shared-beta", "extra-beta"])
        client.beta(["shared-beta"]).messages.create(request, request_opts)

        if beta_header = captured_headers["anthropic-beta"]?
          parts = beta_header.split(",")
          parts.count("shared-beta").should eq(1)
          parts.should contain("extra-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end

    describe "stream" do
      it "merges beta headers in stream request" do
        captured_headers = HTTP::Headers.new
        sse = TestHelpers.stream_sse(["Hello"])

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body_io: IO::Memory.new(sse),
              headers: HTTP::Headers{
                "Content-Type"  => "text/event-stream",
                "Cache-Control" => "no-cache",
              },
            )
          end

        client = TestHelpers.test_client
        request = Anthropic::Messages::Request.new(
          Anthropic::Model.sonnet,
          [Anthropic::Message.user("Hi")],
          1024
        )

        events = [] of Anthropic::StreamEvent
        client.beta(["stream-beta"]).messages.stream(request) { |event| events << event }

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("stream-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end

        events.should_not be_empty
      end

      it "merges beta headers in stream with convenience overload" do
        captured_headers = HTTP::Headers.new
        sse = TestHelpers.stream_sse(["Test"])

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body_io: IO::Memory.new(sse),
              headers: HTTP::Headers{
                "Content-Type"  => "text/event-stream",
                "Cache-Control" => "no-cache",
              },
            )
          end

        client = TestHelpers.test_client

        events = [] of Anthropic::StreamEvent
        client.beta(["stream-convenience-beta"]).messages.stream(
          Anthropic::Model.sonnet,
          [Anthropic::Message.user("Hi")],
          1024
        ) { |event| events << event }

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("stream-convenience-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end

      it "merges per-request beta headers with namespace in stream" do
        captured_headers = HTTP::Headers.new
        sse = TestHelpers.stream_sse(["Hi"])

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body_io: IO::Memory.new(sse),
              headers: HTTP::Headers{
                "Content-Type"  => "text/event-stream",
                "Cache-Control" => "no-cache",
              },
            )
          end

        client = TestHelpers.test_client
        request = Anthropic::Messages::Request.new(
          Anthropic::Model.sonnet,
          [Anthropic::Message.user("Hi")],
          1024
        )
        request_opts = Anthropic::RequestOptions.new(beta_headers: ["stream-request-beta"])
        client.beta(["stream-namespace-beta"]).messages.stream(request, request_opts) { |_ev| }

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("stream-namespace-beta")
          beta_header.should contain("stream-request-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end

    describe "count_tokens" do
      it "merges beta headers in count_tokens request" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages/count_tokens")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: %({"input_tokens": 42}),
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        request = Anthropic::Messages::CountTokensRequest.new(
          Anthropic::Model.sonnet,
          [Anthropic::Message.user("Hello")]
        )
        client.beta(["count-beta"]).messages.count_tokens(request)

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("count-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end

      it "merges beta headers in count_tokens with convenience overload" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages/count_tokens")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: %({"input_tokens": 15}),
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        response = client.beta(["count-convenience-beta"]).messages.count_tokens(
          Anthropic::Model.sonnet,
          [Anthropic::Message.user("Test")],
          system: "You are helpful"
        )

        response.input_tokens.should eq(15)

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("count-convenience-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end

      it "merges per-request beta headers with namespace in count_tokens" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages/count_tokens")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: %({"input_tokens": 20}),
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        request = Anthropic::Messages::CountTokensRequest.new(
          Anthropic::Model.sonnet,
          [Anthropic::Message.user("Test")]
        )
        request_opts = Anthropic::RequestOptions.new(beta_headers: ["request-count-beta"])
        client.beta(["namespace-count-beta"]).messages.count_tokens(request, request_opts)

        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("namespace-count-beta")
          beta_header.should contain("request-count-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end
  end

  describe "beta.messages.batches" do
    describe "#create" do
      it "merges beta headers when creating a batch from request struct" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages/batches")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: {
                id:                "batch_new",
                type:              "message_batch",
                processing_status: "in_progress",
                request_counts:    {processing: 1, succeeded: 0, errored: 0, canceled: 0, expired: 0},
                created_at:        "2025-01-01T00:00:00Z",
              }.to_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        requests = [
          Anthropic::CreateMessageBatchRequest::BatchRequest.new(
            custom_id: "req_1",
            params: {"model" => JSON::Any.new("claude-sonnet-4-6")},
          ),
        ]
        batch_req = Anthropic::CreateMessageBatchRequest.new(requests)

        batch = client.beta(["custom-beta-2025"]).messages.batches.create(batch_req)

        batch.id.should eq("batch_new")
        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("custom-beta-2025")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end

      it "merges beta headers when creating a batch from array" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages/batches")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: {
                id:                "batch_array",
                type:              "message_batch",
                processing_status: "in_progress",
                request_counts:    {processing: 1, succeeded: 0, errored: 0, canceled: 0, expired: 0},
                created_at:        "2025-01-01T00:00:00Z",
              }.to_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        requests = [
          Anthropic::CreateMessageBatchRequest::BatchRequest.new(
            custom_id: "req_1",
            params: {"model" => JSON::Any.new("claude-sonnet-4-6")},
          ),
        ]

        batch = client.beta(["batch-feature"]).messages.batches.create(requests)

        batch.id.should eq("batch_array")
        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("batch-feature")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end

    describe "#list" do
      it "merges beta headers when listing batches" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: {
                data: [
                  {id: "batch_1", type: "message_batch", processing_status: "succeeded",
                   request_counts: {processing: 0, succeeded: 5, errored: 0, canceled: 0, expired: 0},
                   created_at: "2025-01-01T00:00:00Z"},
                ],
                has_more: false,
              }.to_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        page = client.beta(["list-beta-feature"]).messages.batches.list

        page.data.size.should eq(1)
        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("list-beta-feature")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end

    describe "#retrieve" do
      it "merges beta headers when retrieving a batch" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_123")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: {
                id:                "batch_123",
                type:              "message_batch",
                processing_status: "succeeded",
                request_counts:    {processing: 0, succeeded: 10, errored: 0, canceled: 0, expired: 0},
                created_at:        "2025-01-01T00:00:00Z",
              }.to_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        batch = client.beta(["retrieve-beta"]).messages.batches.retrieve("batch_123")

        batch.id.should eq("batch_123")
        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("retrieve-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end

    describe "#cancel" do
      it "merges beta headers when canceling a batch" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages/batches/batch_456/cancel")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: {
                id:                "batch_456",
                type:              "message_batch",
                processing_status: "cancelling",
                request_counts:    {processing: 5, succeeded: 3, errored: 0, canceled: 0, expired: 0},
                created_at:        "2025-01-01T00:00:00Z",
              }.to_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        batch = client.beta(["cancel-beta"]).messages.batches.cancel("batch_456")

        batch.processing_status.should eq("cancelling")
        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("cancel-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end

    describe "#delete" do
      it "merges beta headers when deleting a batch" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:delete, "https://api.anthropic.com/v1/messages/batches/batch_789")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: {
                id:   "batch_789",
                type: "message_batch_deleted",
              }.to_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        deleted = client.beta(["delete-beta"]).messages.batches.delete("batch_789")

        deleted.id.should eq("batch_789")
        deleted.type.should eq("message_batch_deleted")
        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("delete-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end

    describe "#results" do
      it "merges beta headers in both retrieve and results fetch" do
        captured_headers_retrieve = HTTP::Headers.new
        captured_headers_results = HTTP::Headers.new
        ndjson = <<-JSON
          {"custom_id":"req_1","result":{"type":"succeeded","message":{"id":"msg_1","type":"message","role":"assistant","content":[{"type":"text","text":"OK"}],"model":"claude-sonnet-4-20250514","stop_reason":"end_turn","usage":{"input_tokens":5,"output_tokens":2}}}}
          JSON

        WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_results")
          .to_return do |request|
            captured_headers_retrieve = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: {
                id:                "batch_results",
                type:              "message_batch",
                processing_status: "ended",
                request_counts:    {processing: 0, succeeded: 1, errored: 0, canceled: 0, expired: 0},
                created_at:        "2025-01-01T00:00:00Z",
                results_url:       "/v1/messages/batches/batch_results/results",
              }.to_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_results/results")
          .to_return do |request|
            captured_headers_results = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body_io: IO::Memory.new(ndjson),
              headers: HTTP::Headers{"Content-Type" => "application/x-ndjson"},
            )
          end

        client = TestHelpers.test_client
        results = [] of Anthropic::MessageBatchResult
        client.beta(["results-beta"]).messages.batches.results("batch_results") do |result|
          results << result
        end

        results.size.should eq(1)
        results[0].custom_id.should eq("req_1")

        if beta_header = captured_headers_retrieve["anthropic-beta"]?
          beta_header.should contain("results-beta")
        else
          fail "Expected anthropic-beta header in retrieve request"
        end

        if beta_header = captured_headers_results["anthropic-beta"]?
          beta_header.should contain("results-beta")
        else
          fail "Expected anthropic-beta header in results fetch request"
        end
      end
    end

    describe "#list_all" do
      it "merges beta headers through pagination" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: {
                data: [
                  {id: "batch_1", type: "message_batch", processing_status: "succeeded",
                   request_counts: {processing: 0, succeeded: 5, errored: 0, canceled: 0, expired: 0},
                   created_at: "2025-01-01T00:00:00Z"},
                ],
                has_more: false,
              }.to_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        batches = client.beta(["list-all-beta"]).messages.batches.list_all.to_a

        batches.size.should eq(1)
        batches[0].id.should eq("batch_1")
        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("list-all-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end

    describe "per-request options merging" do
      it "merges namespace, per-request, and extra headers" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_merge")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: {
                id:                "batch_merge",
                type:              "message_batch",
                processing_status: "succeeded",
                request_counts:    {processing: 0, succeeded: 1, errored: 0, canceled: 0, expired: 0},
                created_at:        "2025-01-01T00:00:00Z",
              }.to_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        request_opts = Anthropic::RequestOptions.new(
          beta_headers: ["request-level-beta"],
          extra_headers: HTTP::Headers{"X-Custom" => ["custom-value"]},
        )

        batch = client.beta(["namespace-beta"]).messages.batches.retrieve("batch_merge", request_opts)

        batch.id.should eq("batch_merge")
        if beta_header = captured_headers["anthropic-beta"]?
          beta_header.should contain("namespace-beta")
          beta_header.should contain("request-level-beta")
        else
          fail "Expected anthropic-beta header to be present"
        end

        if custom = captured_headers["X-Custom"]?
          custom.should contain("custom-value")
        else
          fail "Expected X-Custom header to be present"
        end
      end

      it "deduplicates beta headers from namespace and request options" do
        captured_headers = HTTP::Headers.new

        WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_dedup")
          .to_return do |request|
            captured_headers = request.headers
            HTTP::Client::Response.new(
              status_code: 200,
              body: {
                id:                "batch_dedup",
                type:              "message_batch",
                processing_status: "succeeded",
                request_counts:    {processing: 0, succeeded: 1, errored: 0, canceled: 0, expired: 0},
                created_at:        "2025-01-01T00:00:00Z",
              }.to_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        request_opts = Anthropic::RequestOptions.new(beta_headers: ["shared-beta"])

        batch = client.beta(["shared-beta"]).messages.batches.retrieve("batch_dedup", request_opts)

        batch.id.should eq("batch_dedup")
        if beta_header = captured_headers["anthropic-beta"]?
          parts = beta_header.split(",")
          parts.count("shared-beta").should eq(1)
        else
          fail "Expected anthropic-beta header to be present"
        end
      end
    end
  end

  describe "extra_body and extra_query preservation" do
    describe "beta.messages.create" do
      it "preserves extra_query in request URL" do
        # WebMock URL matching will fail if query params are missing
        WebMock.stub(:post, "https://api.anthropic.com/v1/messages?custom_param=custom_value")
          .to_return(
            status: 200,
            body: TestHelpers.response_json(text: "Response"),
            headers: {"Content-Type" => "application/json"},
          )

        client = TestHelpers.test_client
        request = Anthropic::Messages::Request.new(
          Anthropic::Model.sonnet,
          [Anthropic::Message.user("Hi")],
          1024
        )
        extra_query = {"custom_param" => "custom_value"}
        request_opts = Anthropic::RequestOptions.new(extra_query: extra_query)
        response = client.beta(["beta-feature"]).messages.create(request, request_opts)
        response.id.should_not be_empty
      end

      it "preserves extra_body in request body" do
        captured_body = ""

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
          .to_return do |request|
            captured_body = request.body.to_s
            HTTP::Client::Response.new(
              status_code: 200,
              body: TestHelpers.response_json(text: "Response"),
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        request = Anthropic::Messages::Request.new(
          Anthropic::Model.sonnet,
          [Anthropic::Message.user("Hi")],
          1024
        )
        extra_body = {"custom_field" => JSON::Any.new("custom_value")}
        request_opts = Anthropic::RequestOptions.new(extra_body: extra_body)
        client.beta(["beta-feature"]).messages.create(request, request_opts)

        captured_body.should contain("custom_field")
        captured_body.should contain("custom_value")
      end
    end

    describe "beta.models.list" do
      it "preserves extra_query in request URL" do
        WebMock.stub(:get, "https://api.anthropic.com/v1/models?debug=true")
          .to_return(
            status: 200,
            body: %({"data": [], "has_more": false}),
            headers: {"Content-Type" => "application/json"},
          )

        client = TestHelpers.test_client
        extra_query = {"debug" => "true"}
        request_opts = Anthropic::RequestOptions.new(extra_query: extra_query)
        response = client.beta(["beta-feature"]).models.list(request_options: request_opts)
        response.data.should be_empty
      end
    end

    describe "beta.files operations" do
      it "preserves extra_query through files.list" do
        WebMock.stub(:get, "https://api.anthropic.com/v1/files?filter=active")
          .to_return(
            status: 200,
            body: {data: [] of String, has_more: false}.to_json,
            headers: {"Content-Type" => "application/json"},
          )

        client = TestHelpers.test_client
        extra_query = {"filter" => "active"}
        request_opts = Anthropic::RequestOptions.new(extra_query: extra_query)
        response = client.beta(["files-beta"]).files.list(request_options: request_opts)
        response.data.should be_empty
      end

      it "preserves extra_query through files.retrieve" do
        WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_123?include=metadata")
          .to_return(
            status: 200,
            body: {id: "file_123", type: "file", filename: "test.txt", size_bytes: 100, created_at: "2025-01-01T00:00:00Z"}.to_json,
            headers: {"Content-Type" => "application/json"},
          )

        client = TestHelpers.test_client
        extra_query = {"include" => "metadata"}
        request_opts = Anthropic::RequestOptions.new(extra_query: extra_query)
        file = client.beta(["files-beta"]).files.retrieve("file_123", request_opts)
        file.id.should eq("file_123")
      end
    end

    describe "beta.messages.batches operations" do
      it "preserves extra_query through batches.list" do
        WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches?status=completed")
          .to_return(
            status: 200,
            body: {data: [] of String, has_more: false}.to_json,
            headers: {"Content-Type" => "application/json"},
          )

        client = TestHelpers.test_client
        extra_query = {"status" => "completed"}
        request_opts = Anthropic::RequestOptions.new(extra_query: extra_query)
        response = client.beta(["batches-beta"]).messages.batches.list(request_options: request_opts)
        response.data.should be_empty
      end

      it "preserves extra_body through batches.create" do
        captured_body = ""

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages/batches")
          .to_return do |request|
            captured_body = request.body.to_s
            HTTP::Client::Response.new(
              status_code: 200,
              body: {
                id:                "batch_new",
                type:              "message_batch",
                processing_status: "in_progress",
                request_counts:    {processing: 1, succeeded: 0, errored: 0, canceled: 0, expired: 0},
                created_at:        "2025-01-01T00:00:00Z",
              }.to_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"},
            )
          end

        client = TestHelpers.test_client
        requests = [
          Anthropic::CreateMessageBatchRequest::BatchRequest.new(
            custom_id: "req_1",
            params: {"model" => JSON::Any.new("claude-sonnet-4-6")},
          ),
        ]
        batch_req = Anthropic::CreateMessageBatchRequest.new(requests)
        extra_body = {"priority" => JSON::Any.new("high")}
        request_opts = Anthropic::RequestOptions.new(extra_body: extra_body)
        client.beta(["batches-beta"]).messages.batches.create(batch_req, request_opts)

        captured_body.should contain("priority")
        captured_body.should contain("high")
      end
    end
  end
end
