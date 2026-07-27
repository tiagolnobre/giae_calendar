class FetchUserPhotoJob < ApplicationScraperJob
  queue_as :default

  def perform(user)
    user = user.is_a?(User) ? user : User.find(user)

    with_session(user) do |scraper|
      data = scraper.fetch_avaliacoes
      guidutente = data[:guidutente]

      next if guidutente.blank?

      image_data = scraper.fetch_foto_utente(guidutente)
      next if image_data.blank?

      user.photo.attach(
        io: StringIO.new(image_data.dup.force_encoding("BINARY")),
        filename: "#{user.giae_username}_#{guidutente}.jpg",
        content_type: "image/jpeg"
      )
    end
  end
end
