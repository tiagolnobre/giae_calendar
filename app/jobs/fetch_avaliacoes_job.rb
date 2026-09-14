class FetchAvaliacoesJob < ApplicationScraperJob
  queue_as :default

  def perform(child)
    child = child.is_a?(Child) ? child : Child.find(child)

    with_session(child) do |scraper|
      data = scraper.fetch_avaliacoes

      ActiveRecord::Base.transaction do
        tipos = data[:tiposavaliacoes]
        disciplinas = data[:disciplinas]
        avaliacoes = data[:avaliacoes]
        avaliacaofinal = data[:avaliacaofinal]

        next if tipos.empty?

        dates = tipos.map { |t| t["datainicio"] }.compact
        reference_date = dates.any? ? Date.parse(dates.min) : Date.today
        school_year_label = SchoolYear.label_from_date(reference_date)

        school_year = SchoolYear.find_or_create_by!(user: child.user, child: child, label: school_year_label)

        school_year.evaluation_types.destroy_all
        tipos.each do |t|
          school_year.evaluation_types.create!(
            idtipoavaliacao: t["idtipoavaliacao"],
            descricao: t["descricao"],
            sigla: t["sigla"],
            start_date: t["datainicio"]
          )
        end

        school_year.subjects.destroy_all
        disciplinas.each do |d|
          school_year.subjects.create!(
            idmatriculadisciplina: d["idmatriculadisciplina"],
            iddisciplina: d["iddisciplina"],
            sigla: d["sigla"],
            descricao: d["descricao"],
            ordem: d["ordem"]
          )
        end

        school_year.evaluations.destroy_all
        subject_map = school_year.subjects.index_by(&:idmatriculadisciplina)
        type_map = school_year.evaluation_types.index_by(&:idtipoavaliacao)

        avaliacoes.each do |a|
          subject = subject_map[a["idmatriculadisciplina"]]
          eval_type = type_map[a["idtipoavaliacao"]]
          next unless subject && eval_type

          school_year.evaluations.create!(
            subject: subject,
            evaluation_type: eval_type,
            idavaliacao: a["idavaliacao"],
            data: a["data"],
            avaliacao: a["avaliacao"],
            avaliacaodescricao: a["avaliacaodescricao"],
            positiva: a["positiva"],
            alinea: a["alinea"],
            alineadescricao: a["alineadescricao"],
            sintesedescritiva: a["sintesedescritiva"],
            disciplina: a["disciplina"],
            tipoavaliacao: a["tipoavaliacao"],
            situacao: a["situacao"],
            dataresultadofinal: a["dataresultadofinal"],
            idmrf: a["idmrf"],
            ativo: a["ativo"],
            final: false
          )
        end

        FetchUserPhotoJob.perform_later(child, data[:guidutente]) if data[:guidutente].present?

        school_year.final_evaluations.destroy_all
        avaliacaofinal.each do |f|
          school_year.final_evaluations.create!(
            idmatricula: f["idmatricula"],
            descricaorfa: f["descricaorfa"],
            positivorfa: f["positivorfa"],
            descricaorfc: f["descricaorfc"],
            positivorfc: f["positivorfc"]
          )
        end
      end
    end
  end
end