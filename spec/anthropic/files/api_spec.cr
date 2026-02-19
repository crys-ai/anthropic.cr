require "../../spec_helper"

describe Anthropic::UploadFileRequest do
  describe ".from_string" do
    it "creates request with owned bytes independent of original string" do
      # Create a string and build the request
      original = "test content data"
      request = Anthropic::UploadFileRequest.from_string("test.txt", original, "text/plain")

      # Modify the original string to prove bytes are independent
      original_bytes = original.to_slice
      request.content.should eq(original_bytes)
      request.content.should_not be(original_bytes) # Different memory

      # Verify the content is a proper owned copy
      request.content.should be_a(Bytes)
      request.filename.should eq("test.txt")
      request.mime_type.should eq("text/plain")
    end

    it "stores a duplicate of the string's bytes" do
      # Create request from a string in a separate scope
      request = Anthropic::UploadFileRequest.from_string("doc.txt", "hello world")

      # The content should still be valid and correct
      request.content.should eq("hello world".to_slice)
      request.content.size.should eq(11)
    end
  end

  describe ".from_base64" do
    it "decodes base64 content" do
      encoded = Base64.strict_encode("decoded content")
      request = Anthropic::UploadFileRequest.from_base64("file.txt", encoded)

      request.content.should eq("decoded content".to_slice)
    end
  end

  describe "#initialize" do
    it "accepts Bytes directly" do
      bytes = Bytes[1, 2, 3, 4, 5]
      request = Anthropic::UploadFileRequest.new("binary.bin", bytes, "application/octet-stream")

      request.content.should eq(bytes)
      request.filename.should eq("binary.bin")
      request.mime_type.should eq("application/octet-stream")
    end

    it "allows nil mime_type" do
      request = Anthropic::UploadFileRequest.new("file.txt", Bytes.empty)
      request.mime_type.should be_nil
    end
  end
end

describe Anthropic::File do
  describe "JSON deserialization" do
    it "parses a file response with size_bytes" do
      json = <<-JSON
        {
          "id": "file_123",
          "type": "file",
          "filename": "document.pdf",
          "size_bytes": 1024,
          "created_at": "2025-01-01T00:00:00Z",
          "mime_type": "application/pdf",
          "downloadable": true
        }
        JSON

      file = Anthropic::File.from_json(json)
      file.id.should eq("file_123")
      file.filename.should eq("document.pdf")
      file.size_bytes.should eq(1024)
      file.mime_type.should eq("application/pdf")
      file.downloadable.should be_true
    end

    it "rejects a payload using the legacy bytes key" do
      json = <<-JSON
        {
          "id": "file_123",
          "type": "file",
          "filename": "document.pdf",
          "bytes": 1024,
          "created_at": "2025-01-01T00:00:00Z"
        }
        JSON

      expect_raises(JSON::SerializableError) do
        Anthropic::File.from_json(json)
      end
    end
  end

  describe "#initialize" do
    it "creates with required fields" do
      file = Anthropic::File.new(
        id: "file_abc",
        filename: "test.txt",
        size_bytes: 100_i64,
        created_at: "2025-01-01T00:00:00Z",
      )

      file.id.should eq("file_abc")
      file.type.should eq("file")
      file.size_bytes.should eq(100)
      file.mime_type.should be_nil
    end
  end

  describe "JSON round-trip" do
    it "serializes size_bytes to the correct key" do
      file = Anthropic::File.new(
        id: "file_rt",
        filename: "round.txt",
        size_bytes: 256_i64,
        created_at: "2025-06-01T00:00:00Z",
      )

      parsed = JSON.parse(file.to_json)
      parsed["size_bytes"].as_i64.should eq(256)
    end
  end
end

describe Anthropic::FileDeleted do
  describe "JSON deserialization" do
    it "parses a file_deleted response" do
      json = <<-JSON
        {
          "id": "file_abc123",
          "type": "file_deleted"
        }
        JSON

      result = Anthropic::FileDeleted.from_json(json)
      result.id.should eq("file_abc123")
      result.type.should eq("file_deleted")
    end
  end
end

describe Anthropic::Files::API do
  describe "#upload" do
    it "includes filename in the multipart file Content-Disposition" do
      captured_body = ""
      response_json = {
        id:         "file_up1",
        type:       "file",
        filename:   "example.txt",
        size_bytes: 11,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.from_string("example.txt", "hello world", "text/plain")
      file = client.files.upload(req)

      file.id.should eq("file_up1")
      file.filename.should eq("example.txt")
      # Verify the multipart body includes filename in the file part's Content-Disposition
      captured_body.should contain(%(name="file"; filename="example.txt"))
    end

    it "includes Content-Type for the file part when mime_type is set" do
      captured_body = ""
      response_json = {
        id:         "file_up2",
        type:       "file",
        filename:   "data.json",
        size_bytes: 2,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.from_string("data.json", "{}", "application/json")
      client.files.upload(req)

      captured_body.should contain("Content-Type: application/json")
      captured_body.should contain(%(filename="data.json"))
    end

    it "uploads via convenience method with filename in Content-Disposition" do
      captured_body = ""
      response_json = {
        id:         "file_up3",
        type:       "file",
        filename:   "readme.md",
        size_bytes: 7,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      file = client.files.upload("readme.md", "# Hello")

      file.id.should eq("file_up3")
      file.filename.should eq("readme.md")
      captured_body.should contain(%(filename="readme.md"))
    end

    it "forwards request_options to client" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .with(headers: {"X-Upload-Header" => "upload-value"})
        .to_return(
          status: 200,
          body: {
            id:         "file_up_opts",
            type:       "file",
            filename:   "test.txt",
            size_bytes: 5,
            created_at: "2025-01-01T00:00:00Z",
          }.to_json,
          headers: HTTP::Headers{"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.from_string("test.txt", "hello")
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Upload-Header" => "upload-value"}
      )

      file = client.files.upload(req, options)
      file.id.should eq("file_up_opts")
    end

    it "multipart Content-Type wins over caller extra_headers Content-Type" do
      captured_content_type = ""
      response_json = {
        id:         "file_ct",
        type:       "file",
        filename:   "test.txt",
        size_bytes: 5,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          if ct = request.headers["Content-Type"]?
            captured_content_type = ct
          end
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.from_string("test.txt", "hello")
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"Content-Type" => "text/plain"}
      )

      file = client.files.upload(req, options)
      file.id.should eq("file_ct")
      captured_content_type.should contain("multipart/form-data; boundary=")
      captured_content_type.should_not eq("text/plain")
    end

    it "forwards beta headers via request_options" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .with(headers: {"anthropic-beta" => "files-beta"})
        .to_return(
          status: 200,
          body: {
            id:         "file_up_beta",
            type:       "file",
            filename:   "beta.txt",
            size_bytes: 3,
            created_at: "2025-01-01T00:00:00Z",
          }.to_json,
          headers: HTTP::Headers{"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.from_string("beta.txt", "abc")
      options = Anthropic::RequestOptions.new(beta_headers: ["files-beta"])

      client.files.upload(req, options)
    end

    it "forwards request_options via convenience method" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .with(headers: {"X-Convenience" => "yes"})
        .to_return(
          status: 200,
          body: {
            id:         "file_conv",
            type:       "file",
            filename:   "conv.txt",
            size_bytes: 4,
            created_at: "2025-01-01T00:00:00Z",
          }.to_json,
          headers: HTTP::Headers{"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Convenience" => "yes"}
      )

      file = client.files.upload("conv.txt", "test", request_options: options)
      file.id.should eq("file_conv")
    end

    it "escapes double quotes in filename" do
      captured_body = ""
      response_json = {
        id:         "file_esc_q",
        type:       "file",
        filename:   "safe.txt",
        size_bytes: 5,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.from_string("file\"name.txt", "hello")
      client.files.upload(req)

      captured_body.should contain(%(filename="file\\"name.txt"))
      captured_body.should_not contain(%(filename="file"name.txt"))
    end

    it "strips CRLF from filename to prevent header injection" do
      captured_body = ""
      response_json = {
        id:         "file_esc_crlf",
        type:       "file",
        filename:   "safe.txt",
        size_bytes: 5,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.from_string("evil\r\nInjected-Header: bad", "hello")
      client.files.upload(req)

      captured_body.should contain(%(filename="evilInjected-Header: bad"))
      captured_body.should_not contain("evil\r\nInjected-Header")
    end

    it "escapes backslashes in filename" do
      captured_body = ""
      response_json = {
        id:         "file_esc_bs",
        type:       "file",
        filename:   "safe.txt",
        size_bytes: 5,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.from_string("path\\to\\file.txt", "hello")
      client.files.upload(req)

      captured_body.should contain(%(filename="path\\\\to\\\\file.txt"))
    end

    it "passes normal filenames through unchanged" do
      captured_body = ""
      response_json = {
        id:         "file_normal",
        type:       "file",
        filename:   "normal.txt",
        size_bytes: 5,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.from_string("my-file_2025.txt", "hello")
      client.files.upload(req)

      captured_body.should contain(%(filename="my-file_2025.txt"))
    end

    it "omits Content-Type when mime_type contains CRLF injection attempt" do
      captured_body = ""
      response_json = {
        id:         "file_mime_crlf",
        type:       "file",
        filename:   "test.txt",
        size_bytes: 5,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.new("test.txt", "hello".to_slice, "text/plain\r\nX-Injected: evil")
      client.files.upload(req)

      # After CRLF stripping the value becomes "text/plainX-Injected: evil"
      # which contains a space, so valid_mime_type? rejects it and Content-Type is omitted
      captured_body.should_not contain("text/plain\r\nX-Injected")
      lines = captured_body.split("\r\n")
      file_part_content_types = lines.select { |line| line.starts_with?("Content-Type:") && !line.includes?("multipart/form-data") }
      file_part_content_types.should be_empty
    end

    it "preserves valid mime types unchanged" do
      captured_body = ""
      response_json = {
        id:         "file_mime_valid",
        type:       "file",
        filename:   "data.json",
        size_bytes: 2,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.from_string("data.json", "{}", "application/json")
      client.files.upload(req)

      captured_body.should contain("Content-Type: application/json")
    end

    it "omits Content-Type header when mime_type is empty after sanitization" do
      captured_body = ""
      response_json = {
        id:         "file_mime_empty",
        type:       "file",
        filename:   "test.txt",
        size_bytes: 5,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      # mime_type that becomes empty after CRLF stripping
      req = Anthropic::UploadFileRequest.new("test.txt", "hello".to_slice, "\r\n")
      client.files.upload(req)

      # Should NOT have a Content-Type line for the file part
      lines = captured_body.split("\r\n")
      file_part_content_types = lines.select { |line| line.starts_with?("Content-Type:") && !line.includes?("multipart/form-data") }
      file_part_content_types.should be_empty
    end

    it "omits Content-Type header when mime_type has no slash" do
      captured_body = ""
      response_json = {
        id:         "file_mime_noslash",
        type:       "file",
        filename:   "test.txt",
        size_bytes: 5,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.new("test.txt", "hello".to_slice, "textplain")
      client.files.upload(req)

      lines = captured_body.split("\r\n")
      file_part_content_types = lines.select { |line| line.starts_with?("Content-Type:") && !line.includes?("multipart/form-data") }
      file_part_content_types.should be_empty
    end

    it "omits Content-Type header when mime_type contains spaces" do
      captured_body = ""
      response_json = {
        id:         "file_mime_spaces",
        type:       "file",
        filename:   "test.txt",
        size_bytes: 5,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.new("test.txt", "hello".to_slice, "text / plain")
      client.files.upload(req)

      lines = captured_body.split("\r\n")
      file_part_content_types = lines.select { |line| line.starts_with?("Content-Type:") && !line.includes?("multipart/form-data") }
      file_part_content_types.should be_empty
    end

    it "preserves valid mime types with parameters" do
      captured_body = ""
      response_json = {
        id:         "file_mime_params",
        type:       "file",
        filename:   "test.txt",
        size_bytes: 5,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.from_string("test.txt", "hello", "text/plain")
      client.files.upload(req)

      captured_body.should contain("Content-Type: text/plain")
    end

    it "omits Content-Type header when mime_type contains tab character" do
      captured_body = ""
      response_json = {
        id:         "file_mime_tab",
        type:       "file",
        filename:   "test.txt",
        size_bytes: 5,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.new("test.txt", "hello".to_slice, "text/\tplain")
      client.files.upload(req)

      lines = captured_body.split("\r\n")
      file_part_content_types = lines.select { |line| line.starts_with?("Content-Type:") && !line.includes?("multipart/form-data") }
      file_part_content_types.should be_empty
    end

    it "omits Content-Type header when mime_type contains control character" do
      captured_body = ""
      response_json = {
        id:         "file_mime_ctrl",
        type:       "file",
        filename:   "test.txt",
        size_bytes: 5,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      WebMock.stub(:post, "https://api.anthropic.com/v1/files")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.new("test.txt", "hello".to_slice, "text/pl\x01ain")
      client.files.upload(req)

      lines = captured_body.split("\r\n")
      file_part_content_types = lines.select { |line| line.starts_with?("Content-Type:") && !line.includes?("multipart/form-data") }
      file_part_content_types.should be_empty
    end

    it "preserves extra_query params in upload request URL" do
      response_json = {
        id:         "file_extra_query",
        type:       "file",
        filename:   "test.txt",
        size_bytes: 5,
        created_at: "2025-01-01T00:00:00Z",
      }.to_json

      # WebMock URL matching verifies the query params are present
      WebMock.stub(:post, "https://api.anthropic.com/v1/files?custom_param=custom_value&debug=true")
        .to_return(
          status: 200,
          body: response_json,
          headers: HTTP::Headers{"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.from_string("test.txt", "hello")
      options = Anthropic::RequestOptions.new(
        extra_query: {"custom_param" => "custom_value", "debug" => "true"}
      )

      file = client.files.upload(req, options)
      file.id.should eq("file_extra_query")
    end

    it "raises ArgumentError when extra_body is used with upload" do
      client = TestHelpers.test_client
      req = Anthropic::UploadFileRequest.from_string("test.txt", "hello")
      options = Anthropic::RequestOptions.new(
        extra_body: {"custom_field" => JSON::Any.new("extra_value")}
      )

      # Multipart uploads cannot merge extra_body, so we raise early
      expect_raises(ArgumentError, /extra_body cannot be used with multipart file uploads/) do
        client.files.upload(req, options)
      end
    end
  end

  describe "#list" do
    it "returns paginated files" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "file_1", type: "file", filename: "doc1.pdf", size_bytes: 1024, created_at: "2025-01-01T00:00:00Z"},
            ],
            has_more: false,
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      page = client.files.list

      page.data.size.should eq(1)
      page.data[0].filename.should eq("doc1.pdf")
      page.data[0].size_bytes.should eq(1024)
      page.has_more?.should be_false
    end

    it "forwards request_options to client" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files")
        .with(headers: {"X-List-Header" => "list-value"})
        .to_return(
          status: 200,
          body: {data: [] of String, has_more: false}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-List-Header" => "list-value"}
      )

      page = client.files.list(request_options: options)
      page.should be_a(Anthropic::Page(Anthropic::File))
    end

    it "forwards beta headers via request_options" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files")
        .with(headers: {"anthropic-beta" => "files-list-beta"})
        .to_return(
          status: 200,
          body: {data: [] of String, has_more: false}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(beta_headers: ["files-list-beta"])

      client.files.list(request_options: options)
    end
  end

  describe "#retrieve" do
    it "returns a specific file" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_123")
        .to_return(
          status: 200,
          body: {
            id:         "file_123",
            type:       "file",
            filename:   "document.pdf",
            size_bytes: 2048,
            created_at: "2025-01-01T00:00:00Z",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      file = client.files.retrieve("file_123")

      file.id.should eq("file_123")
      file.filename.should eq("document.pdf")
      file.size_bytes.should eq(2048)
    end

    it "forwards request_options to client" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_retrieve")
        .with(headers: {"X-Retrieve-Header" => "retrieve-value"})
        .to_return(
          status: 200,
          body: {
            id:         "file_retrieve",
            type:       "file",
            filename:   "retrieved.txt",
            size_bytes: 100,
            created_at: "2025-01-01T00:00:00Z",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Retrieve-Header" => "retrieve-value"}
      )

      file = client.files.retrieve("file_retrieve", options)
      file.id.should eq("file_retrieve")
    end

    it "encodes file_id with slashes in path" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file%2Fwith%2Fslashes")
        .to_return(
          status: 200,
          body: {
            id:         "file/with/slashes",
            type:       "file",
            filename:   "slashed.txt",
            size_bytes: 50,
            created_at: "2025-01-01T00:00:00Z",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      file = client.files.retrieve("file/with/slashes")
      file.id.should eq("file/with/slashes")
    end

    it "encodes file_id with query and fragment characters in path" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/id%3Fquery%23fragment")
        .to_return(
          status: 200,
          body: {
            id:         "id?query#fragment",
            type:       "file",
            filename:   "special.txt",
            size_bytes: 25,
            created_at: "2025-01-01T00:00:00Z",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      file = client.files.retrieve("id?query#fragment")
      file.id.should eq("id?query#fragment")
    end
  end

  describe "#delete" do
    it "sends DELETE to /v1/files/{id} and returns FileDeleted" do
      WebMock.stub(:delete, "https://api.anthropic.com/v1/files/file_123")
        .to_return(
          status: 200,
          body: {id: "file_123", type: "file_deleted"}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      result = client.files.delete("file_123")

      result.id.should eq("file_123")
      result.type.should eq("file_deleted")
    end

    it "does not send POST to the legacy delete path" do
      # Stub the wrong (legacy) endpoint - should NOT be hit
      WebMock.stub(:post, "https://api.anthropic.com/v1/files/file_456/delete")
        .to_return(status: 200, body: "{}")

      # Stub the correct DELETE endpoint
      WebMock.stub(:delete, "https://api.anthropic.com/v1/files/file_456")
        .to_return(
          status: 200,
          body: {id: "file_456", type: "file_deleted"}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      result = client.files.delete("file_456")
      result.id.should eq("file_456")
    end

    it "forwards request_options to client" do
      WebMock.stub(:delete, "https://api.anthropic.com/v1/files/file_del")
        .with(headers: {"X-Delete-Header" => "delete-value"})
        .to_return(
          status: 200,
          body: {id: "file_del", type: "file_deleted"}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Delete-Header" => "delete-value"}
      )

      result = client.files.delete("file_del", options)
      result.id.should eq("file_del")
    end

    it "encodes file_id with reserved characters in path" do
      WebMock.stub(:delete, "https://api.anthropic.com/v1/files/file%2Fwith%2Fslashes")
        .to_return(
          status: 200,
          body: {id: "file/with/slashes", type: "file_deleted"}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      result = client.files.delete("file/with/slashes")
      result.id.should eq("file/with/slashes")
    end
  end

  describe "#download" do
    it "returns owned bytes that survive response lifetime" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_dl/content")
        .to_return(
          status: 200,
          body: "binary data",
          headers: {"Content-Type" => "application/octet-stream"},
        )

      client = TestHelpers.test_client
      data = client.files.download("file_dl")

      data.should eq("binary data".to_slice)
      # Verify it's a proper Bytes (Slice(UInt8))
      data.should be_a(Bytes)
    end

    it "forwards request_options to client" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_dl_opts/content")
        .with(headers: {"X-Download-Header" => "download-value"})
        .to_return(
          status: 200,
          body: "downloaded content",
          headers: {"Content-Type" => "application/octet-stream"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Download-Header" => "download-value"}
      )

      data = client.files.download("file_dl_opts", options)
      data.should eq("downloaded content".to_slice)
    end

    it "encodes file_id with reserved characters in download path" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file%2Fwith%2Fslashes/content")
        .to_return(
          status: 200,
          body: "encoded download",
          headers: {"Content-Type" => "application/octet-stream"},
        )

      client = TestHelpers.test_client
      data = client.files.download("file/with/slashes")
      data.should eq("encoded download".to_slice)
    end
  end

  describe "#download_string" do
    it "downloads file content" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_123/content")
        .to_return(
          status: 200,
          body: "File content here",
          headers: {"Content-Type" => "text/plain"},
        )

      client = TestHelpers.test_client
      content = client.files.download_string("file_123")

      content.should eq("File content here")
    end

    it "forwards request_options to client" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_str_opts/content")
        .with(headers: {"X-String-Header" => "string-value"})
        .to_return(
          status: 200,
          body: "string content",
          headers: {"Content-Type" => "text/plain"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-String-Header" => "string-value"}
      )

      content = client.files.download_string("file_str_opts", options)
      content.should eq("string content")
    end
  end

  describe "#download_base64" do
    it "downloads and encodes file content as base64" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_b64/content")
        .to_return(
          status: 200,
          body: "binary\x00data",
          headers: {"Content-Type" => "application/octet-stream"},
        )

      client = TestHelpers.test_client
      encoded = client.files.download_base64("file_b64")

      encoded.should eq(Base64.strict_encode("binary\x00data"))
    end

    it "forwards request_options to client" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_b64_opts/content")
        .with(headers: {"X-Base64-Header" => "base64-value"})
        .to_return(
          status: 200,
          body: "content to encode",
          headers: {"Content-Type" => "application/octet-stream"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Base64-Header" => "base64-value"}
      )

      encoded = client.files.download_base64("file_b64_opts", options)
      encoded.should eq(Base64.strict_encode("content to encode"))
    end
  end

  describe "#list_all" do
    it "returns an AutoPaginator for lazy iteration" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "file_1", type: "file", filename: "doc1.pdf", size_bytes: 1024, created_at: "2025-01-01T00:00:00Z"},
            ],
            has_more: false,
            first_id: "file_1",
            last_id:  "file_1",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      paginator = client.files.list_all

      paginator.should be_a(Anthropic::AutoPaginator(Anthropic::File))
      files = paginator.to_a
      files.size.should eq(1)
      files[0].id.should eq("file_1")
    end

    it "iterates across multiple pages using after_id cursor" do
      # First page
      WebMock.stub(:get, "https://api.anthropic.com/v1/files?limit=1")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "file_1", type: "file", filename: "doc1.pdf", size_bytes: 1024, created_at: "2025-01-01T00:00:00Z"},
            ],
            has_more: true,
            first_id: "file_1",
            last_id:  "file_1",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      # Second page
      WebMock.stub(:get, "https://api.anthropic.com/v1/files?after_id=file_1&limit=1")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "file_2", type: "file", filename: "doc2.pdf", size_bytes: 2048, created_at: "2025-01-02T00:00:00Z"},
            ],
            has_more: false,
            first_id: "file_2",
            last_id:  "file_2",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      paginator = client.files.list_all(limit: 1)

      ids = [] of String
      paginator.each { |file| ids << file.id }

      ids.should eq(["file_1", "file_2"])
    end

    it "forwards request_options to client for each page fetch" do
      # First page with custom header
      WebMock.stub(:get, "https://api.anthropic.com/v1/files")
        .with(headers: {"X-Paginator-Header" => "paginator-value"})
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "file_p1", type: "file", filename: "page1.txt", size_bytes: 10, created_at: "2025-01-01T00:00:00Z"},
            ],
            has_more: true,
            first_id: "file_p1",
            last_id:  "file_p1",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      # Second page with custom header
      WebMock.stub(:get, "https://api.anthropic.com/v1/files?after_id=file_p1")
        .with(headers: {"X-Paginator-Header" => "paginator-value"})
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "file_p2", type: "file", filename: "page2.txt", size_bytes: 20, created_at: "2025-01-02T00:00:00Z"},
            ],
            has_more: false,
            first_id: "file_p2",
            last_id:  "file_p2",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Paginator-Header" => "paginator-value"}
      )

      ids = [] of String
      client.files.list_all(request_options: options).each { |file| ids << file.id }

      ids.should eq(["file_p1", "file_p2"])
    end

    it "forwards beta headers via request_options" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files")
        .with(headers: {"anthropic-beta" => "files-paginator-beta"})
        .to_return(
          status: 200,
          body: {
            data:     [] of String,
            has_more: false,
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(beta_headers: ["files-paginator-beta"])

      files = client.files.list_all(request_options: options).to_a
      files.should be_empty
    end
  end
end
