require "test_helper"

class AvaliacoesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!
  end

  test "should get index" do
    get avaliacoes_path
    assert_response :success
    assert_select "h1", I18n.t("avaliacoes.title")
  end

  test "should redirect to sign_in when not authenticated" do
    delete sign_out_path
    get avaliacoes_path
    assert_redirected_to %r{/sign_in}
  end

  test "shows no data message when no school_year exists" do
    get avaliacoes_path
    assert_response :success
    assert_match I18n.t("avaliacoes.no_data"), response.body
    assert_select "button", I18n.t("avaliacoes.fetch_now")
  end

  test "shows school year label when data exists" do
    school_year = SchoolYear.create!(user: @user, label: "2025/2026")
    school_year.subjects.create!(idmatriculadisciplina: 1, sigla: "PORT", descricao: "Português", ordem: 1)
    eval_type = school_year.evaluation_types.create!(idtipoavaliacao: 1, sigla: "1P", descricao: "1st Period")
    subject = school_year.subjects.first
    school_year.evaluations.create!(subject: subject, evaluation_type: eval_type, idavaliacao: 1, avaliacao: "MB")

    get avaliacoes_path
    assert_response :success
    assert_match "2025/2026", response.body
    assert_match "PORT", response.body
    assert_match "MB", response.body
  end

  test "shows full subject name on desktop" do
    school_year = SchoolYear.create!(user: @user, label: "2025/2026")
    school_year.subjects.create!(idmatriculadisciplina: 1, sigla: "PORT", descricao: "Português", ordem: 1)

    get avaliacoes_path
    assert_response :success
    assert_select ".hidden.sm\\:inline", text: "Português"
  end

  test "shows subject acronym on mobile" do
    school_year = SchoolYear.create!(user: @user, label: "2025/2026")
    school_year.subjects.create!(idmatriculadisciplina: 1, sigla: "PORT", descricao: "Português", ordem: 1)

    get avaliacoes_path
    assert_response :success
    assert_select ".sm\\:hidden", text: "PORT"
  end

  test "shows evaluation types in table headers" do
    school_year = SchoolYear.create!(user: @user, label: "2025/2026")
    school_year.evaluation_types.create!(idtipoavaliacao: 1, sigla: "1P", descricao: "1st Period")
    school_year.evaluation_types.create!(idtipoavaliacao: 2, sigla: "2P", descricao: "2nd Period")

    get avaliacoes_path
    assert_response :success
    assert_select "th[title=\"1st Period\"]", text: "1P"
    assert_select "th[title=\"2nd Period\"]", text: "2P"
  end

  test "shows final evaluations section" do
    school_year = SchoolYear.create!(user: @user, label: "2025/2026")
    school_year.final_evaluations.create!(descricaorfa: "Transitou", positivorfa: true)

    get avaliacoes_path
    assert_response :success
    assert_select "h2", I18n.t("avaliacoes.final_evaluation")
    assert_match "Transitou", response.body
  end

  test "refresh enqueues FetchAvaliacoesJob" do
    assert_enqueued_with(job: FetchAvaliacoesJob) do
      post refresh_avaliacoes_path
    end
  end

  test "refresh redirects to index" do
    post refresh_avaliacoes_path
    assert_redirected_to avaliacoes_url(locale: I18n.locale)
  end

  test "shows dashes for missing evaluations" do
    school_year = SchoolYear.create!(user: @user, label: "2025/2026")
    school_year.subjects.create!(idmatriculadisciplina: 1, sigla: "PORT", descricao: "Português", ordem: 1)
    school_year.evaluation_types.create!(idtipoavaliacao: 1, sigla: "1P", descricao: "1st Period")

    get avaliacoes_path
    assert_response :success
    assert_select "td .text-gray-300", "\u2014"
  end

  test "handles alinea descriptions" do
    school_year = SchoolYear.create!(user: @user, label: "2025/2026")
    subject = school_year.subjects.create!(idmatriculadisciplina: 1, sigla: "AEST", descricao: "Apoio ao Estudo", ordem: 1)
    eval_type = school_year.evaluation_types.create!(idtipoavaliacao: 1, sigla: "1P", descricao: "1st Period")
    school_year.evaluations.create!(
      subject: subject, evaluation_type: eval_type, idavaliacao: 1,
      alinea: "x", alineadescricao: "Disciplina Semestral."
    )

    get avaliacoes_path
    assert_response :success
    assert_match "Disciplina Semestral.", response.body
  end

  test "subjects ordered by ordem" do
    school_year = SchoolYear.create!(user: @user, label: "2025/2026")
    school_year.subjects.create!(idmatriculadisciplina: 2, sigla: "MAT", descricao: "Matemática", ordem: 2)
    school_year.subjects.create!(idmatriculadisciplina: 1, sigla: "PORT", descricao: "Português", ordem: 1)

    get avaliacoes_path
    assert_response :success
    assert_match /Português.*Matemática/m, response.body
  end

  test "evaluation types ordered by start_date" do
    school_year = SchoolYear.create!(user: @user, label: "2025/2026")
    school_year.evaluation_types.create!(idtipoavaliacao: 2, sigla: "2P", descricao: "2nd Period", start_date: "2026-01-05")
    school_year.evaluation_types.create!(idtipoavaliacao: 1, sigla: "1P", descricao: "1st Period", start_date: "2025-09-11")

    get avaliacoes_path
    assert_response :success
    assert_match /1P.*2P/m, response.body
  end
end
