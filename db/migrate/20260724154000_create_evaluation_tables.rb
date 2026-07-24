class CreateEvaluationTables < ActiveRecord::Migration[8.1]
  def change
    create_table :school_years do |t|
      t.references :user, null: false, foreign_key: true
      t.string :label, null: false
      t.timestamps
      t.index [:user_id, :label], unique: true
    end

    create_table :subjects do |t|
      t.references :school_year, null: false, foreign_key: true
      t.integer :idmatriculadisciplina, null: false
      t.integer :iddisciplina
      t.string :sigla
      t.string :descricao
      t.integer :ordem
      t.timestamps
      t.index [:school_year_id, :idmatriculadisciplina], unique: true
    end

    create_table :evaluation_types do |t|
      t.references :school_year, null: false, foreign_key: true
      t.integer :idtipoavaliacao, null: false
      t.string :descricao
      t.string :sigla
      t.date :start_date
      t.timestamps
      t.index [:school_year_id, :idtipoavaliacao], unique: true
    end

    create_table :evaluations do |t|
      t.references :school_year, null: false, foreign_key: true
      t.references :subject, null: false, foreign_key: true
      t.references :evaluation_type, null: false, foreign_key: true
      t.integer :idavaliacao
      t.date :data
      t.string :avaliacao
      t.string :avaliacaodescricao
      t.boolean :positiva
      t.string :alinea
      t.string :alineadescricao
      t.string :sintesedescritiva
      t.string :disciplina
      t.string :tipoavaliacao
      t.string :situacao
      t.date :dataresultadofinal
      t.integer :idmrf
      t.boolean :ativo
      t.boolean :final, default: false, null: false
      t.timestamps
      t.index [:school_year_id, :subject_id, :evaluation_type_id, :final], unique: true, name: "idx_evaluations_on_year_subject_type_final"
    end

    create_table :final_evaluations do |t|
      t.references :school_year, null: false, foreign_key: true, index: false
      t.integer :idmatricula
      t.string :descricaorfa
      t.boolean :positivorfa
      t.string :descricaorfc
      t.boolean :positivorfc
      t.timestamps
      t.index [:school_year_id], unique: true, name: "idx_final_evaluations_on_school_year"
    end
  end
end
