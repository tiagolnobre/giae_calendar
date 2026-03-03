class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @notifications = current_user.notifications.order(created_at: :desc).limit(50)
  end

  def mark_read
    @notification = current_user.notifications.find(params[:id])
    @notification.update!(read_at: Time.current)
    redirect_to notifications_path, notice: "Notificação marcada como lida"
  end
end
