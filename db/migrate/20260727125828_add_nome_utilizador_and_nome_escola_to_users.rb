class AddNomeUtilizadorAndNomeEscolaToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :nome_utilizador, :string
    add_column :users, :nome_escola, :string
  end
end
