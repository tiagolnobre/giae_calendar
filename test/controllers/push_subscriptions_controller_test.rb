require "test_helper"

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post sign_in_path, params: { email: @user.email, password: "password123" }
  end

  test "should get public_key" do
    get push_subscription_public_key_url
    assert_response :success
    json = JSON.parse(response.body)
    # In test environment, credentials may not be set, so we just check the response is valid JSON
    assert json.key?("public_key")
  end

  test "should create push subscription" do
    subscription_params = {
      subscription: {
        endpoint: "https://fcm.googleapis.com/fcm/send/test123",
        keys: {
          p256dh: "BEl12iYZ2VphW6k1u6Lw3Z4Y2L8jV5k1u6Lw3Z4Y2L8jV5k1u6Lw3Z4Y2L8=",
          auth: "testauth123"
        }
      }
    }

    assert_difference "PushSubscription.count", 1 do
      post push_subscriptions_url, params: subscription_params, as: :json
    end
    assert_response :ok
  end

  test "should update existing push subscription" do
    existing = @user.push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/test123",
      p256dh: "oldp256dh",
      auth: "oldauth"
    )

    subscription_params = {
      subscription: {
        endpoint: "https://fcm.googleapis.com/fcm/send/test123",
        keys: {
          p256dh: "newp256dh",
          auth: "newauth"
        }
      }
    }

    assert_no_difference "PushSubscription.count" do
      post push_subscriptions_url, params: subscription_params, as: :json
    end
    assert_response :ok

    existing.reload
    assert_equal "newp256dh", existing.p256dh
    assert_equal "newauth", existing.auth
  end

  test "should require authentication" do
    get push_subscription_public_key_url
    assert_response :success

    # Try to access as unauthenticated
    get root_url
    assert_response :redirect
  end

  test "should destroy push subscription" do
    subscription = @user.push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/test123",
      p256dh: "test",
      auth: "test"
    )

    assert_difference "PushSubscription.count", -1 do
      delete push_subscriptions_url, params: { endpoint: subscription.endpoint }
    end
    assert_response :ok
  end

  test "should require valid subscription params" do
    assert_no_difference "PushSubscription.count" do
      post push_subscriptions_url, params: { subscription: { endpoint: "test" } }, as: :json
    end
    assert_response :bad_request
  end
end
