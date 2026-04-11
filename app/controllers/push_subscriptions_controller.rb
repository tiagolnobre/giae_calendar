# frozen_string_literal: true

class PushSubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def public_key
    render json: { public_key: Rails.application.credentials.dig(:webpush, :vapid_public_key) || ENV.fetch("VAPID_PUBLIC_KEY", "") }
  end

  def create
    endpoint = params.require(:subscription).require(:endpoint)
    p256dh = params.require(:subscription).require(:keys).require(:p256dh)
    auth = params.require(:subscription).require(:keys).require(:auth)

    @push_subscription = current_user.push_subscriptions.find_or_initialize_by(endpoint: endpoint)
    @push_subscription.p256dh = p256dh
    @push_subscription.auth = auth

    if @push_subscription.save
      head :ok
    else
      head :unprocessable_entity
    end
  end

  def destroy
    endpoint = params[:endpoint].presence
    if endpoint.present?
      current_user.push_subscriptions.find_by(endpoint: endpoint)&.destroy
    else
      current_user.push_subscriptions.destroy_all
    end
    head :ok
  end
end
