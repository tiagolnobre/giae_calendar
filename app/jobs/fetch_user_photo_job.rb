class FetchUserPhotoJob < ApplicationScraperJob
  queue_as :default

  PHOTO_HOST = "https://aemgn.giae.pt"

  def perform(user, guidutente = nil, fotoutente = nil)
    user = user.is_a?(User) ? user : User.find(user)

    if guidutente.blank?
      with_session(user) do |scraper|
        data = scraper.fetch_avaliacoes
        guidutente = data[:guidutente]
      end
    end

    return if guidutente.blank?

    photo_url = fotoutente.present? ? "#{PHOTO_HOST}/#{fotoutente}" : "#{PHOTO_HOST}/temp_files/fotos_utentes/#{user.giae_username}_#{guidutente}.jpg"

    image_data = fetch_image(photo_url)
    return if image_data.blank?

    user.update!(photo_data: Base64.strict_encode64(image_data))
  end

  private

  def fetch_image(url)
    uri = URI.parse(url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.open_timeout = 15
    http.read_timeout = 15

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    return nil unless response.code == "200"

    response.body
  end
end
