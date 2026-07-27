require "test_helper"

class FetchUserPhotoJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @job = FetchUserPhotoJob.new
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "job is enqueued with correct queue" do
    assert_equal "default", FetchUserPhotoJob.queue_name
  end

  test "perform stores photo_data when guidutente and image present" do
    guidutente = "e194deee-8df2-4304-918f-db100105273f"
    image_bytes = (+"\xFF\xD8\xFF\xE0\x00\x10JFIF").force_encoding("ASCII-8BIT")

    @job.stubs(:fetch_image).returns(image_bytes)

    @job.perform(@user, guidutente)

    assert_equal Base64.strict_encode64(image_bytes), @user.reload.photo_data
  end

  test "perform uses fotoutente URL when provided" do
    guidutente = "e194deee-8df2-4304-918f-db100105273f"
    fotoutente = "temp_files/fotos_utentes/18210_e194deee-8df2-4304-918f-db100105273f.jpg"
    image_bytes = (+"\xFF\xD8\xFF\xE0\x00\x10JFIF").force_encoding("ASCII-8BIT")

    @job.stubs(:fetch_image).with("https://aemgn.giae.pt/#{fotoutente}").returns(image_bytes)

    @job.perform(@user, guidutente, fotoutente)

    assert_equal Base64.strict_encode64(image_bytes), @user.reload.photo_data
  end

  test "perform does nothing when guidutente is nil" do
    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_avaliacoes).returns({
      guidutente: nil
    })

    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).yields(mock_scraper)
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    @job.perform(@user, nil)

    assert_nil @user.reload.photo_data
  end

  test "perform does nothing when image fetch returns nil" do
    guidutente = "e194deee-8df2-4304-918f-db100105273f"

    @job.stubs(:fetch_image).returns(nil)

    @job.perform(@user, guidutente)

    assert_nil @user.reload.photo_data
  end

  test "perform handles integer user id" do
    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_avaliacoes).returns({
      guidutente: nil
    })

    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).yields(mock_scraper)
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    assert_nothing_raised do
      @job.perform(@user.id, nil)
    end
  end

  test "perform fetches guidutente from session when not provided" do
    image_bytes = (+"\xFF\xD8\xFF\xE0\x00\x10JFIF").force_encoding("ASCII-8BIT")

    @user.update!(giae_username: "12345")

    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_avaliacoes).returns({
      guidutente: "e194deee-8df2-4304-918f-db100105273f"
    })

    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).yields(mock_scraper)
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    @job.stubs(:fetch_image).returns(image_bytes)

    @job.perform(@user)

    assert_equal Base64.strict_encode64(image_bytes), @user.reload.photo_data
  end

  test "perform does nothing when guidutente is nil from session" do
    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_avaliacoes).returns({
      guidutente: nil
    })

    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).yields(mock_scraper)
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    @job.perform(@user)

    assert_nil @user.reload.photo_data
  end

  test "perform re-raises SessionUnavailable error when guidutente not provided" do
    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).raises(GiaeSessionManager::SessionUnavailable, "Session expired")
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    assert_raises(GiaeSessionManager::SessionUnavailable) do
      @job.perform(@user)
    end
  end
end
