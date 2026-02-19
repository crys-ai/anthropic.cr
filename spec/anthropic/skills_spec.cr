require "../spec_helper"

describe Anthropic::Skills::API do
  describe "#list" do
    it "lists skills with default params" do
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
          "has_more": false,
          "next_page": null
        }
        JSON

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills")
        .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      response = client.skills.list

      response.data.size.should eq(1)
      response.has_more?.should be_false

      if skill = response.data.first?
        skill.id.should eq("skill_01ABC123")
        skill.display_title.should eq("PDF Reader")
        skill.source.should eq("anthropic")
        skill.anthropic?.should be_true
        skill.custom?.should be_false
      end
    end

    it "includes beta header in request" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/skills")
        .with(headers: {"anthropic-beta" => "skills-2025-10-02"})
        .to_return(status: 200, body: %({"data": [], "has_more": false}), headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      client.skills.list
    end

    it "filters by source" do
      body = <<-JSON
        {
          "data": [
            {
              "id": "skill_custom",
              "type": "skill",
              "display_title": "My Skill",
              "source": "custom",
              "latest_version": "1759178010641129",
              "created_at": "2025-01-15T12:00:00Z",
              "updated_at": "2025-01-15T12:00:00Z"
            }
          ],
          "has_more": false
        }
        JSON

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills?source=custom")
        .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      params = Anthropic::SkillsListParams.new(source: "custom")
      response = client.skills.list(params)

      response.data.size.should eq(1)

      if skill = response.data.first?
        skill.custom?.should be_true
      end
    end

    it "paginates with limit and page token" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/skills?limit=10&page=next_token_abc")
        .to_return(status: 200, body: %({"data": [], "has_more": true, "next_page": "next_token_def"}), headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      params = Anthropic::SkillsListParams.new(limit: 10, page: "next_token_abc")
      response = client.skills.list(params)

      response.has_more?.should be_true
      response.next_page.should eq("next_token_def")
    end
  end

  describe "#retrieve" do
    it "retrieves a skill by ID" do
      body = <<-JSON
        {
          "id": "skill_01ABC123",
          "type": "skill",
          "display_title": "PDF Reader",
          "source": "anthropic",
          "latest_version": "1759178010641129",
          "created_at": "2025-01-15T12:00:00Z",
          "updated_at": "2025-01-15T12:00:00Z"
        }
        JSON

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills/skill_01ABC123")
        .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      skill = client.skills.retrieve("skill_01ABC123")

      skill.id.should eq("skill_01ABC123")
      skill.display_title.should eq("PDF Reader")
      skill.source_enum.should eq(Anthropic::SkillSource::Anthropic)
    end

    it "encodes skill_id with slashes in path" do
      body = <<-JSON
        {
          "id": "skill/with/slashes",
          "type": "skill",
          "display_title": "Slashed Skill",
          "source": "custom",
          "latest_version": "1759178010641129",
          "created_at": "2025-01-15T12:00:00Z",
          "updated_at": "2025-01-15T12:00:00Z"
        }
        JSON

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills/skill%2Fwith%2Fslashes")
        .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      skill = client.skills.retrieve("skill/with/slashes")
      skill.id.should eq("skill/with/slashes")
    end

    it "encodes skill_id with query and fragment characters in path" do
      body = <<-JSON
        {
          "id": "id?query#fragment",
          "type": "skill",
          "display_title": "Special Skill",
          "source": "custom",
          "latest_version": "1759178010641129",
          "created_at": "2025-01-15T12:00:00Z",
          "updated_at": "2025-01-15T12:00:00Z"
        }
        JSON

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills/id%3Fquery%23fragment")
        .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      skill = client.skills.retrieve("id?query#fragment")
      skill.id.should eq("id?query#fragment")
    end
  end

  describe "#create" do
    it "creates a new skill without upload (sends empty JSON body)" do
      captured_body = ""
      captured_headers = HTTP::Headers.new
      body = <<-JSON
        {
          "id": "skill_new123",
          "type": "skill",
          "display_title": "New Skill",
          "source": "custom",
          "latest_version": "1759178010641129",
          "created_at": "2025-01-15T12:00:00Z",
          "updated_at": "2025-01-15T12:00:00Z"
        }
        JSON

      WebMock.stub(:post, "https://api.anthropic.com/v1/skills")
        .to_return do |request|
          captured_body = request.body.to_s
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: body,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      skill = client.skills.create

      skill.id.should eq("skill_new123")
      skill.custom?.should be_true

      # Verify it sends an empty JSON body (not multipart)
      captured_body.should eq("{}")
      # Content-Type should NOT be multipart for no-upload overload
      if content_type = captured_headers["Content-Type"]?
        content_type.should contain("application/json")
        content_type.should_not contain("multipart")
      end
    end

    it "creates a skill with multipart upload" do
      captured_body = ""
      captured_headers = HTTP::Headers.new
      response_body = <<-JSON
        {
          "id": "skill_upload1",
          "type": "skill",
          "display_title": "Uploaded Skill",
          "source": "custom",
          "latest_version": "1759178010641129",
          "created_at": "2025-01-15T12:00:00Z",
          "updated_at": "2025-01-15T12:00:00Z"
        }
        JSON

      WebMock.stub(:post, "https://api.anthropic.com/v1/skills")
        .to_return do |request|
          captured_body = request.body.to_s
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_body,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      upload = Anthropic::UploadSkillRequest.from_string("zip-content-here", "my_skill.zip")
      skill = client.skills.create(upload)

      skill.id.should eq("skill_upload1")
      skill.custom?.should be_true

      # Verify multipart structure
      captured_body.should contain("Content-Disposition: form-data")
      captured_body.should contain(%(filename="my_skill.zip"))
      captured_body.should contain("Content-Type: application/zip")
      captured_body.should contain("zip-content-here")

      # Verify Content-Type header is multipart
      if content_type = captured_headers["Content-Type"]?
        content_type.should contain("multipart/form-data")
        content_type.should contain("boundary=")
      else
        fail "Expected Content-Type header to be present"
      end
    end

    it "includes beta header in multipart upload" do
      captured_headers = HTTP::Headers.new

      WebMock.stub(:post, "https://api.anthropic.com/v1/skills")
        .to_return do |request|
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: <<-JSON,
              {
                "id": "skill_up2", "type": "skill", "display_title": "Test",
                "source": "custom", "latest_version": "123", "created_at": "2025-01-15T12:00:00Z",
                "updated_at": "2025-01-15T12:00:00Z"
              }
              JSON
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      upload = Anthropic::UploadSkillRequest.new(Bytes[1, 2, 3])
      client.skills.create(upload)

      if beta_header = captured_headers["anthropic-beta"]?
        beta_header.should contain("skills-2025-10-02")
      else
        fail "Expected anthropic-beta header to be present"
      end
    end

    it "escapes double quotes in filename" do
      captured_body = ""

      WebMock.stub(:post, "https://api.anthropic.com/v1/skills")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: <<-JSON,
              {
                "id": "skill_esc_q", "type": "skill", "display_title": "Test",
                "source": "custom", "latest_version": "123", "created_at": "2025-01-15T12:00:00Z",
                "updated_at": "2025-01-15T12:00:00Z"
              }
              JSON
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      upload = Anthropic::UploadSkillRequest.from_string("content", "skill\"name.zip")
      client.skills.create(upload)

      captured_body.should contain(%(filename="skill\\"name.zip"))
      captured_body.should_not contain(%(filename="skill"name.zip"))
    end

    it "strips CRLF from filename to prevent header injection" do
      captured_body = ""

      WebMock.stub(:post, "https://api.anthropic.com/v1/skills")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: <<-JSON,
              {
                "id": "skill_esc_crlf", "type": "skill", "display_title": "Test",
                "source": "custom", "latest_version": "123", "created_at": "2025-01-15T12:00:00Z",
                "updated_at": "2025-01-15T12:00:00Z"
              }
              JSON
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      upload = Anthropic::UploadSkillRequest.from_string("content", "evil\r\nInjected-Header: bad.zip")
      client.skills.create(upload)

      captured_body.should contain(%(filename="evilInjected-Header: bad.zip"))
      captured_body.should_not contain("evil\r\nInjected-Header")
    end

    it "escapes backslashes in filename" do
      captured_body = ""

      WebMock.stub(:post, "https://api.anthropic.com/v1/skills")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: <<-JSON,
              {
                "id": "skill_esc_bs", "type": "skill", "display_title": "Test",
                "source": "custom", "latest_version": "123", "created_at": "2025-01-15T12:00:00Z",
                "updated_at": "2025-01-15T12:00:00Z"
              }
              JSON
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      upload = Anthropic::UploadSkillRequest.from_string("content", "path\\to\\skill.zip")
      client.skills.create(upload)

      captured_body.should contain(%(filename="path\\\\to\\\\skill.zip"))
    end

    it "passes normal filenames through unchanged" do
      captured_body = ""

      WebMock.stub(:post, "https://api.anthropic.com/v1/skills")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: <<-JSON,
              {
                "id": "skill_normal", "type": "skill", "display_title": "Test",
                "source": "custom", "latest_version": "123", "created_at": "2025-01-15T12:00:00Z",
                "updated_at": "2025-01-15T12:00:00Z"
              }
              JSON
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      upload = Anthropic::UploadSkillRequest.from_string("content", "my-skill_2025.zip")
      client.skills.create(upload)

      captured_body.should contain(%(filename="my-skill_2025.zip"))
    end

    it "preserves extra_query params in multipart create request URL" do
      # WebMock URL matching verifies the query param is present
      WebMock.stub(:post, "https://api.anthropic.com/v1/skills?custom_param=custom_value")
        .to_return(
          status: 200,
          body: <<-JSON,
            {
              "id": "skill_eq", "type": "skill", "display_title": "Test",
              "source": "custom", "latest_version": "123", "created_at": "2025-01-15T12:00:00Z",
              "updated_at": "2025-01-15T12:00:00Z"
            }
            JSON
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      upload = Anthropic::UploadSkillRequest.from_string("content", "skill.zip")
      options = Anthropic::RequestOptions.new(
        extra_query: {"custom_param" => "custom_value"}
      )

      skill = client.skills.create(upload, options)
      skill.id.should eq("skill_eq")
    end

    it "raises ArgumentError when extra_body is used with multipart create request" do
      client = TestHelpers.test_client
      upload = Anthropic::UploadSkillRequest.from_string("content", "skill.zip")
      options = Anthropic::RequestOptions.new(
        extra_body: {"custom_field" => JSON::Any.new("extra_value")}
      )

      # Multipart uploads cannot merge extra_body, so we raise early
      expect_raises(ArgumentError, /extra_body cannot be used with multipart skill uploads/) do
        client.skills.create(upload, options)
      end
    end
  end

  describe "#delete" do
    it "deletes a skill" do
      body = <<-JSON
        {
          "id": "skill_01ABC123",
          "type": "skill_deleted"
        }
        JSON

      WebMock.stub(:delete, "https://api.anthropic.com/v1/skills/skill_01ABC123")
        .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      result = client.skills.delete("skill_01ABC123")

      result.id.should eq("skill_01ABC123")
      result.type.should eq("skill_deleted")
    end

    it "encodes skill_id with reserved characters in delete path" do
      body = <<-JSON
        {
          "id": "skill/with/slashes",
          "type": "skill_deleted"
        }
        JSON

      WebMock.stub(:delete, "https://api.anthropic.com/v1/skills/skill%2Fwith%2Fslashes")
        .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      result = client.skills.delete("skill/with/slashes")
      result.id.should eq("skill/with/slashes")
    end
  end

  describe "#list_versions" do
    it "lists versions of a skill" do
      body = <<-JSON
        {
          "data": [
            {
              "id": "sv_01ABC",
              "type": "skill_version",
              "skill_id": "skill_01ABC123",
              "version": "1759178010641129",
              "name": "PDF Reader",
              "description": "Reads PDF files",
              "directory": "pdf_reader",
              "created_at": "2025-01-15T12:00:00Z"
            }
          ],
          "has_more": false
        }
        JSON

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills/skill_01ABC123/versions")
        .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      response = client.skills.list_versions("skill_01ABC123")

      response.data.size.should eq(1)

      if version = response.data.first?
        version.skill_id.should eq("skill_01ABC123")
        version.name.should eq("PDF Reader")
        version.description.should eq("Reads PDF files")
      end
    end

    it "encodes skill_id with reserved characters in list_versions path" do
      body = <<-JSON
        {
          "data": [],
          "has_more": false
        }
        JSON

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills/skill%2Fwith%2Fslashes/versions")
        .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      response = client.skills.list_versions("skill/with/slashes")
      response.data.should be_empty
    end
  end

  describe "#retrieve_version" do
    it "retrieves a specific version" do
      body = <<-JSON
        {
          "id": "sv_01ABC",
          "type": "skill_version",
          "skill_id": "skill_01ABC123",
          "version": "1759178010641129",
          "name": "PDF Reader",
          "description": "Reads PDF files",
          "directory": "pdf_reader",
          "created_at": "2025-01-15T12:00:00Z"
        }
        JSON

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills/skill_01ABC123/versions/1759178010641129")
        .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      version = client.skills.retrieve_version("skill_01ABC123", "1759178010641129")

      version.version.should eq("1759178010641129")
      version.directory.should eq("pdf_reader")
    end

    it "encodes both skill_id and version with reserved characters" do
      body = <<-JSON
        {
          "id": "sv_encoded",
          "type": "skill_version",
          "skill_id": "skill/slashed",
          "version": "v1/beta?test",
          "name": "Encoded Version",
          "description": "Has encoded path",
          "directory": "encoded",
          "created_at": "2025-01-15T12:00:00Z"
        }
        JSON

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills/skill%2Fslashed/versions/v1%2Fbeta%3Ftest")
        .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      version = client.skills.retrieve_version("skill/slashed", "v1/beta?test")
      version.skill_id.should eq("skill/slashed")
      version.version.should eq("v1/beta?test")
    end
  end

  describe "#create_version" do
    it "creates a new version without upload (sends empty JSON body)" do
      captured_body = ""
      captured_headers = HTTP::Headers.new
      body = <<-JSON
        {
          "id": "sv_02DEF",
          "type": "skill_version",
          "skill_id": "skill_01ABC123",
          "version": "1759180000000000",
          "name": "PDF Reader",
          "description": "Reads PDF files",
          "directory": "pdf_reader",
          "created_at": "2025-01-15T14:00:00Z"
        }
        JSON

      WebMock.stub(:post, "https://api.anthropic.com/v1/skills/skill_01ABC123/versions")
        .to_return do |request|
          captured_body = request.body.to_s
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: body,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      version = client.skills.create_version("skill_01ABC123")

      version.version.should eq("1759180000000000")

      # Verify it sends an empty JSON body (not multipart)
      captured_body.should eq("{}")
      # Content-Type should NOT be multipart for no-upload overload
      if content_type = captured_headers["Content-Type"]?
        content_type.should contain("application/json")
        content_type.should_not contain("multipart")
      end
    end

    it "creates a new version with multipart upload" do
      captured_body = ""
      captured_headers = HTTP::Headers.new
      response_body = <<-JSON
        {
          "id": "sv_03GHI",
          "type": "skill_version",
          "skill_id": "skill_01ABC123",
          "version": "1759190000000000",
          "name": "PDF Reader v2",
          "description": "Reads PDF files better",
          "directory": "pdf_reader",
          "created_at": "2025-01-15T16:00:00Z"
        }
        JSON

      WebMock.stub(:post, "https://api.anthropic.com/v1/skills/skill_01ABC123/versions")
        .to_return do |request|
          captured_body = request.body.to_s
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: response_body,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      upload = Anthropic::UploadSkillRequest.from_string("new-version-content", "skill_v2.zip")
      version = client.skills.create_version("skill_01ABC123", upload)

      version.version.should eq("1759190000000000")
      version.name.should eq("PDF Reader v2")

      # Verify multipart structure
      captured_body.should contain("Content-Disposition: form-data")
      captured_body.should contain(%(filename="skill_v2.zip"))
      captured_body.should contain("new-version-content")

      # Verify Content-Type header is multipart
      if content_type = captured_headers["Content-Type"]?
        content_type.should contain("multipart/form-data")
      else
        fail "Expected Content-Type header to be present"
      end
    end

    it "includes beta header in multipart version upload" do
      captured_headers = HTTP::Headers.new

      WebMock.stub(:post, "https://api.anthropic.com/v1/skills/skill_01ABC123/versions")
        .to_return do |request|
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: <<-JSON,
              {
                "id": "sv_04", "type": "skill_version", "skill_id": "skill_01ABC123",
                "version": "1759200000000000", "name": "Test", "description": "Desc",
                "directory": "test", "created_at": "2025-01-15T12:00:00Z"
              }
              JSON
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      upload = Anthropic::UploadSkillRequest.new(Bytes[1, 2, 3])
      client.skills.create_version("skill_01ABC123", upload)

      if beta_header = captured_headers["anthropic-beta"]?
        beta_header.should contain("skills-2025-10-02")
      else
        fail "Expected anthropic-beta header to be present"
      end
    end

    it "preserves extra_query params in multipart create_version request URL" do
      # WebMock URL matching verifies the query param is present
      WebMock.stub(:post, "https://api.anthropic.com/v1/skills/skill_01ABC123/versions?trace=true")
        .to_return(
          status: 200,
          body: <<-JSON,
            {
              "id": "sv_eq", "type": "skill_version", "skill_id": "skill_01ABC123",
              "version": "1759200000000000", "name": "Test", "description": "Desc",
              "directory": "test", "created_at": "2025-01-15T12:00:00Z"
            }
            JSON
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      upload = Anthropic::UploadSkillRequest.from_string("content", "skill.zip")
      options = Anthropic::RequestOptions.new(
        extra_query: {"trace" => "true"}
      )

      version = client.skills.create_version("skill_01ABC123", upload, options)
      version.id.should eq("sv_eq")
    end

    it "raises ArgumentError when extra_body is used with multipart create_version request" do
      client = TestHelpers.test_client
      upload = Anthropic::UploadSkillRequest.from_string("content", "skill.zip")
      options = Anthropic::RequestOptions.new(
        extra_body: {"custom_field" => JSON::Any.new("extra_value")}
      )

      # Multipart uploads cannot merge extra_body, so we raise early
      expect_raises(ArgumentError, /extra_body cannot be used with multipart skill uploads/) do
        client.skills.create_version("skill_01ABC123", upload, options)
      end
    end
  end

  describe "#delete_version" do
    it "deletes a specific version" do
      body = <<-JSON
        {
          "id": "1759178010641129",
          "type": "skill_version_deleted"
        }
        JSON

      WebMock.stub(:delete, "https://api.anthropic.com/v1/skills/skill_01ABC123/versions/1759178010641129")
        .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      result = client.skills.delete_version("skill_01ABC123", "1759178010641129")

      result.id.should eq("1759178010641129")
      result.type.should eq("skill_version_deleted")
    end

    it "encodes both skill_id and version with reserved characters in delete_version path" do
      body = <<-JSON
        {
          "id": "v1/beta",
          "type": "skill_version_deleted"
        }
        JSON

      WebMock.stub(:delete, "https://api.anthropic.com/v1/skills/skill%2Fslashed/versions/v1%2Fbeta")
        .to_return(status: 200, body: body, headers: {"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      result = client.skills.delete_version("skill/slashed", "v1/beta")
      result.id.should eq("v1/beta")
    end
  end

  describe "extra_body and extra_query preservation" do
    it "preserves extra_query through skills.list" do
      # WebMock URL matching verifies the query param is present
      WebMock.stub(:get, "https://api.anthropic.com/v1/skills?verbose=true")
        .to_return(
          status: 200,
          body: %({"data": [], "has_more": false}),
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      extra_query = {"verbose" => "true"}
      request_opts = Anthropic::RequestOptions.new(extra_query: extra_query)
      response = client.skills.list(request_options: request_opts)
      response.data.should be_empty
    end

    it "preserves extra_body through skills.create (no-upload overload)" do
      captured_body = ""

      WebMock.stub(:post, "https://api.anthropic.com/v1/skills")
        .to_return do |request|
          captured_body = request.body.to_s
          HTTP::Client::Response.new(
            status_code: 200,
            body: <<-JSON,
              {
                "id": "skill_extra", "type": "skill", "display_title": "Test",
                "source": "custom", "latest_version": "123", "created_at": "2025-01-15T12:00:00Z",
                "updated_at": "2025-01-15T12:00:00Z"
              }
              JSON
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      extra_body = {"metadata" => JSON::Any.new("extra_info")}
      request_opts = Anthropic::RequestOptions.new(extra_body: extra_body)
      client.skills.create(request_opts)

      captured_body.should contain("metadata")
      captured_body.should contain("extra_info")
    end

    it "preserves extra_query through skills.retrieve" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/skills/skill_01ABC123?expand=versions")
        .to_return(
          status: 200,
          body: <<-JSON,
            {
              "id": "skill_01ABC123", "type": "skill", "display_title": "Test",
              "source": "custom", "latest_version": "123", "created_at": "2025-01-15T12:00:00Z",
              "updated_at": "2025-01-15T12:00:00Z"
            }
            JSON
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      extra_query = {"expand" => "versions"}
      request_opts = Anthropic::RequestOptions.new(extra_query: extra_query)
      skill = client.skills.retrieve("skill_01ABC123", request_opts)
      skill.id.should eq("skill_01ABC123")
    end
  end
end

describe Anthropic::SkillSource do
  describe "#to_s" do
    it "converts custom to string" do
      Anthropic::SkillSource::Custom.to_s.should eq("custom")
    end

    it "converts anthropic to string" do
      Anthropic::SkillSource::Anthropic.to_s.should eq("anthropic")
    end
  end

  describe ".parse?" do
    it "parses custom" do
      result = Anthropic::SkillSource.parse?("custom")
      result.should eq(Anthropic::SkillSource::Custom)
    end

    it "parses anthropic" do
      result = Anthropic::SkillSource.parse?("anthropic")
      result.should eq(Anthropic::SkillSource::Anthropic)
    end

    it "returns nil for unknown" do
      Anthropic::SkillSource.parse?("unknown").should be_nil
    end

    it "is case insensitive" do
      Anthropic::SkillSource.parse?("CUSTOM").should eq(Anthropic::SkillSource::Custom)
    end
  end
end

describe Anthropic::SkillsListParams do
  describe "validation" do
    it "raises ArgumentError for zero limit" do
      expect_raises(ArgumentError, /limit must be positive/) do
        Anthropic::SkillsListParams.new(limit: 0)
      end
    end

    it "raises ArgumentError for negative limit" do
      expect_raises(ArgumentError, /limit must be positive/) do
        Anthropic::SkillsListParams.new(limit: -1)
      end
    end

    it "accepts positive limit" do
      params = Anthropic::SkillsListParams.new(limit: 10)
      params.limit.should eq(10)
    end

    it "accepts nil limit" do
      params = Anthropic::SkillsListParams.new
      params.limit.should be_nil
    end

    it "raises ArgumentError for unknown source value" do
      expect_raises(ArgumentError, /source must be/) do
        Anthropic::SkillsListParams.new(source: "invalid")
      end
    end

    it "accepts custom source" do
      params = Anthropic::SkillsListParams.new(source: "custom")
      params.source.should eq("custom")
    end

    it "accepts anthropic source" do
      params = Anthropic::SkillsListParams.new(source: "anthropic")
      params.source.should eq("anthropic")
    end

    it "accepts uppercase CUSTOM source (case-insensitive)" do
      params = Anthropic::SkillsListParams.new(source: "CUSTOM")
      params.source.should eq("CUSTOM")
    end

    it "accepts mixed-case Custom source (case-insensitive)" do
      params = Anthropic::SkillsListParams.new(source: "Custom")
      params.source.should eq("Custom")
    end

    it "accepts uppercase ANTHROPIC source (case-insensitive)" do
      params = Anthropic::SkillsListParams.new(source: "ANTHROPIC")
      params.source.should eq("ANTHROPIC")
    end

    it "accepts mixed-case Anthropic source (case-insensitive)" do
      params = Anthropic::SkillsListParams.new(source: "Anthropic")
      params.source.should eq("Anthropic")
    end

    it "preserves original casing of source value" do
      params = Anthropic::SkillsListParams.new(source: "CUSTOM")
      params.source.should eq("CUSTOM")
    end

    it "accepts nil source" do
      params = Anthropic::SkillsListParams.new
      params.source.should be_nil
    end
  end

  describe "#to_query_string" do
    it "returns empty string with no params" do
      params = Anthropic::SkillsListParams.new
      params.to_query_string.should eq("")
    end

    it "builds query with limit" do
      params = Anthropic::SkillsListParams.new(limit: 10)
      params.to_query_string.should eq("?limit=10")
    end

    it "builds query with all params" do
      params = Anthropic::SkillsListParams.new(limit: 10, page: "token123", source: "custom")
      params.to_query_string.should contain("limit=10")
      params.to_query_string.should contain("page=token123")
      params.to_query_string.should contain("source=custom")
    end

    it "encodes special characters in page token using query-component encoding" do
      params = Anthropic::SkillsListParams.new(page: "token/with spaces+and&special=chars")
      qs = params.to_query_string
      # URI::Params.build uses www-form encoding: spaces become +, special chars are percent-encoded
      qs.should_not contain("token/with spaces+and&special=chars")
      qs.should contain("page=")
      # Verify it starts with ?
      qs.starts_with?("?").should be_true
    end

    it "includes source value in query string" do
      params = Anthropic::SkillsListParams.new(source: "custom")
      qs = params.to_query_string
      qs.should contain("source=custom")
    end
  end
end

describe Anthropic::SkillVersionsListParams do
  describe "validation" do
    it "raises ArgumentError for zero limit" do
      expect_raises(ArgumentError, /limit must be positive/) do
        Anthropic::SkillVersionsListParams.new(limit: 0)
      end
    end

    it "raises ArgumentError for negative limit" do
      expect_raises(ArgumentError, /limit must be positive/) do
        Anthropic::SkillVersionsListParams.new(limit: -1)
      end
    end

    it "accepts positive limit" do
      params = Anthropic::SkillVersionsListParams.new(limit: 10)
      params.limit.should eq(10)
    end

    it "accepts nil limit" do
      params = Anthropic::SkillVersionsListParams.new
      params.limit.should be_nil
    end
  end

  describe "#to_query_string" do
    it "returns empty string with no params" do
      params = Anthropic::SkillVersionsListParams.new
      params.to_query_string.should eq("")
    end

    it "builds query with limit" do
      params = Anthropic::SkillVersionsListParams.new(limit: 5)
      params.to_query_string.should eq("?limit=5")
    end

    it "builds query with limit and page" do
      params = Anthropic::SkillVersionsListParams.new(limit: 5, page: "next_abc")
      params.to_query_string.should contain("limit=5")
      params.to_query_string.should contain("page=next_abc")
    end

    it "encodes special characters in page token" do
      params = Anthropic::SkillVersionsListParams.new(page: "token+with/special chars")
      qs = params.to_query_string
      qs.should_not contain("token+with/special chars")
      qs.should contain("page=")
    end
  end
end

describe Anthropic::UploadSkillRequest do
  describe ".from_file" do
    it "creates request with owned bytes from file content" do
      File.tempfile("skill_test", ".zip") do |temp_file|
        content = "PK\x03\x04test zip content bytes".to_slice
        temp_file.write(content)
        temp_file.flush

        request = Anthropic::UploadSkillRequest.from_file(temp_file.path)

        # Verify content matches
        request.content.should eq(content)
        request.filename.should eq(File.basename(temp_file.path))
      end
    end

    it "creates independent bytes not aliasing file read buffer" do
      File.tempfile("skill_owned", ".zip") do |temp_file|
        original_content = "original skill zip data"
        temp_file.print(original_content)
        temp_file.flush

        request = Anthropic::UploadSkillRequest.from_file(temp_file.path)

        # Content should match the original file content
        request.content.should eq(original_content.to_slice)

        # The returned bytes are writable (owned copy via .dup), proving
        # they are independent of any read-only string buffer.
        # Mutate a copy of request.content to prove it's owned and writable.
        owned_bytes = request.content
        if owned_bytes.size > 0
          original_first_byte = owned_bytes[0]
          owned_bytes[0] = 0_u8
          # The mutation worked, proving the slice is writable (owned)
          owned_bytes[0].should eq(0_u8)
          # Restore it
          owned_bytes[0] = original_first_byte
        end

        # Content should still match the original after restore
        request.content.should eq(original_content.to_slice)
      end
    end

    it "uses file basename as filename" do
      File.tempfile("my_skill", ".zip") do |temp_file|
        temp_file.print("content")
        temp_file.flush

        request = Anthropic::UploadSkillRequest.from_file(temp_file.path)
        expected_name = File.basename(temp_file.path)

        request.filename.should eq(expected_name)
      end
    end
  end

  describe ".from_string" do
    it "creates request with owned bytes independent of original string" do
      original = "test skill content"
      request = Anthropic::UploadSkillRequest.from_string(original, "my_skill.zip")

      # Verify content matches
      original_bytes = original.to_slice
      request.content.should eq(original_bytes)
      # Verify it's a different memory allocation (owned copy)
      request.content.should_not be(original_bytes)

      request.content.should be_a(Bytes)
      request.filename.should eq("my_skill.zip")
    end

    it "stores a duplicate of the string's bytes" do
      request = Anthropic::UploadSkillRequest.from_string("hello skill world")

      request.content.should eq("hello skill world".to_slice)
      request.content.size.should eq(17)
      request.filename.should eq("skill.zip") # default filename
    end

    it "uses default filename when not specified" do
      request = Anthropic::UploadSkillRequest.from_string("content")
      request.filename.should eq("skill.zip")
    end
  end

  describe ".from_base64" do
    it "decodes base64 content" do
      encoded = Base64.strict_encode("decoded skill content")
      request = Anthropic::UploadSkillRequest.from_base64(encoded, "skill.zip")

      request.content.should eq("decoded skill content".to_slice)
    end
  end

  describe "#initialize" do
    it "accepts Bytes directly" do
      bytes = Bytes[10, 20, 30, 40, 50]
      request = Anthropic::UploadSkillRequest.new(bytes, "custom.zip")

      request.content.should eq(bytes)
      request.filename.should eq("custom.zip")
    end

    it "uses default filename" do
      request = Anthropic::UploadSkillRequest.new(Bytes.empty)
      request.filename.should eq("skill.zip")
    end
  end
end

describe Anthropic::Skill do
  it "parses from JSON" do
    json = <<-JSON
      {
        "id": "skill_01ABC123",
        "type": "skill",
        "display_title": "PDF Reader",
        "source": "anthropic",
        "latest_version": "1759178010641129",
        "created_at": "2025-01-15T12:00:00Z",
        "updated_at": "2025-01-15T12:00:00Z"
      }
      JSON

    skill = Anthropic::Skill.from_json(json)
    skill.id.should eq("skill_01ABC123")
    skill.type.should eq("skill")
    skill.display_title.should eq("PDF Reader")
    skill.source.should eq("anthropic")
    skill.latest_version.should eq("1759178010641129")
  end
end

describe Anthropic::SkillVersion do
  it "parses from JSON" do
    json = <<-JSON
      {
        "id": "sv_01ABC",
        "type": "skill_version",
        "skill_id": "skill_01ABC123",
        "version": "1759178010641129",
        "name": "PDF Reader",
        "description": "Reads PDF files",
        "directory": "pdf_reader",
        "created_at": "2025-01-15T12:00:00Z"
      }
      JSON

    version = Anthropic::SkillVersion.from_json(json)
    version.id.should eq("sv_01ABC")
    version.skill_id.should eq("skill_01ABC123")
    version.version.should eq("1759178010641129")
    version.name.should eq("PDF Reader")
    version.description.should eq("Reads PDF files")
    version.directory.should eq("pdf_reader")
  end
end
