class FetchUserPhotoJob < ApplicationScraperJob
  queue_as :default

  def perform(user, guidutente = nil)
    user = user.is_a?(User) ? user : User.find(user)

    if guidutente.blank?
      with_session(user) do |scraper|
        data = scraper.fetch_avaliacoes
        guidutente = data[:guidutente]
      end
    end

    return if guidutente.blank?
    return unless user.giae_username

    scraper = GiaeScraperService.new(
      username: user.giae_username,
      password: user.giae_password,
      login_url: Rails.application.config.giae_login_url,
      school_code: user.giae_school_code
    )

    image_data = scraper.fetch_foto_utente(guidutente)
    return if image_data.blank?

    user.photo.attach(
      io: StringIO.new(image_data.dup.force_encoding("BINARY")),
      filename: "#{user.giae_username}_#{guidutente}.jpg",
      content_type: "image/jpeg"
    )
  end
end
