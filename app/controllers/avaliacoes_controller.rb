class AvaliacoesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_child!

  def index
    @child = current_child
    @school_year = @child.school_years.order(created_at: :desc).first
    @error = nil

    if @school_year.nil?
      @avaliacoes_data = nil
    end
  end

  def refresh
    @child = current_child

    FetchAvaliacoesJob.perform_later(@child.id)

    redirect_to avaliacoes_path, notice: t("avaliacoes.refreshing")
  end

  private

  def require_child!
    redirect_to children_path, alert: t("children.need_one") and return unless current_child
  end
end