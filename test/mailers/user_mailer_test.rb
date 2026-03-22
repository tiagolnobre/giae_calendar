# frozen_string_literal: true

require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:one)
  end

  test "notification_email sends email with correct attributes" do
    title = "Test Notification"
    body = "This is a test notification body"

    email = UserMailer.notification_email(@user, title, body)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ @user.email ], email.to
    assert_equal title, email.subject
    assert_match body, email.body.to_s
  end

  test "notification_email uses html format" do
    title = "HTML Test"
    body = "<p>HTML content</p>"

    email = UserMailer.notification_email(@user, title, body)

    assert email.content_type.include?("text/html")
    # Email body should contain the HTML content
    assert_match title, email.body.to_s
    assert_match body, email.body.to_s
  end
end
