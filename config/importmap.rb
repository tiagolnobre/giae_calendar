# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@github/combobox-nav", to: "https://cdn.jsdelivr.net/npm/@github/combobox-nav@2.0.0/+esm"

# Pin all controllers
pin_all_from "app/javascript/controllers", under: "controllers"
