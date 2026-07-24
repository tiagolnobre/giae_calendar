class AvaliacoesController < ApplicationController
  before_action :authenticate_user!

  def index
    @user = current_user
    @avaliacoes_data = nil
    @error = nil

    begin
      GiaeSessionManager.new(@user).with_active_session do |scraper|
        @avaliacoes_data = scraper.fetch_avaliacoes
      end
    rescue GiaeSessionManager::SessionUnavailable, GiaeScraperService::Error => e
      @error = e.message
      Rails.logger.error "[AvaliacoesController] Error fetching data for user #{@user.id}: #{e.message}"
    end
  end
end
