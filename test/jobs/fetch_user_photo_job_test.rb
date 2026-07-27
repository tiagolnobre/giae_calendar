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

  test "perform attaches photo when guidutente and image present" do
    guidutente = "e194deee-8df2-4304-918f-db100105273f"
    image_bytes = (+"\xFF\xD8\xFF\xE0\x00\x10JFIF").force_encoding("ASCII-8BIT")

    @user.update!(giae_username: "12345")

    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_foto_utente).with(guidutente).returns(image_bytes)

    GiaeScraperService.stubs(:new).returns(mock_scraper)

    assert_difference "ActiveStorage::Blob.count", 1 do
      @job.perform(@user, guidutente)
    end

    assert @user.photo.attached?
    assert_equal "image/jpeg", @user.photo.content_type
  end

  test "perform does nothing when guidutente is nil" do
    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_avaliacoes).returns({
      guidutente: nil
    })

    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).yields(mock_scraper)
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    assert_no_difference "ActiveStorage::Blob.count" do
      @job.perform(@user, nil)
    end
  end

  test "perform does nothing when image fetch returns nil" do
    guidutente = "e194deee-8df2-4304-918f-db100105273f"

    @user.update!(giae_username: "12345")

    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_foto_utente).returns(nil)

    GiaeScraperService.stubs(:new).returns(mock_scraper)

    assert_no_difference "ActiveStorage::Blob.count" do
      @job.perform(@user, guidutente)
    end
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

    mock_photo_scraper = mock("photo_scraper")
    mock_photo_scraper.stubs(:fetch_foto_utente).returns(image_bytes)
    GiaeScraperService.stubs(:new).returns(mock_photo_scraper)

    assert_difference "ActiveStorage::Blob.count", 1 do
      @job.perform(@user)
    end
  end

  test "perform does nothing when guidutente is nil from session" do
    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_avaliacoes).returns({
      guidutente: nil
    })

    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).yields(mock_scraper)
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    assert_no_difference "ActiveStorage::Blob.count" do
      @job.perform(@user)
    end
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
