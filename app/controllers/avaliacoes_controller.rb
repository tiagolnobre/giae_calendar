class AvaliacoesController < ApplicationController
  before_action :authenticate_user!

  def index
    @user = current_user
    @school_year = @user.school_years.order(created_at: :desc).first
    @error = nil

    if @school_year.nil?
      @avaliacoes_data = nil
    end
  end

  def refresh
    @user = current_user

    FetchAvaliacoesJob.perform_later(@user.id)

    redirect_to avaliacoes_path, notice: t("avaliacoes.refreshing")
  end
end
