# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def notification_email(user, title, body)
    @user = user
    @title = title
    @body = body

    mail(to: user.email, subject: @title)
  end
end
