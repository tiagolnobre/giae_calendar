require "test_helper"

class EvaluationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @school_year = SchoolYear.create!(user: @user, label: "2025/2026")
    @subject = @school_year.subjects.create!(idmatriculadisciplina: 1, sigla: "PORT", descricao: "Português")
    @eval_type = @school_year.evaluation_types.create!(idtipoavaliacao: 1, sigla: "1P", descricao: "1st Period")
  end

  test "should be valid with required associations" do
    evaluation = Evaluation.new(
      school_year: @school_year,
      subject: @subject,
      evaluation_type: @eval_type,
      idavaliacao: 1
    )
    assert evaluation.valid?
  end

  test "belongs to school_year" do
    evaluation = Evaluation.create!(school_year: @school_year, subject: @subject, evaluation_type: @eval_type, idavaliacao: 1)
    assert_equal @school_year, evaluation.school_year
  end

  test "belongs to subject" do
    evaluation = Evaluation.create!(school_year: @school_year, subject: @subject, evaluation_type: @eval_type, idavaliacao: 1)
    assert_equal @subject, evaluation.subject
  end

  test "belongs to evaluation_type" do
    evaluation = Evaluation.create!(school_year: @school_year, subject: @subject, evaluation_type: @eval_type, idavaliacao: 1)
    assert_equal @eval_type, evaluation.evaluation_type
  end

  test "stores grade fields" do
    evaluation = Evaluation.create!(
      school_year: @school_year,
      subject: @subject,
      evaluation_type: @eval_type,
      idavaliacao: 1,
      data: Date.parse("2025-12-19"),
      avaliacao: "MB",
      avaliacaodescricao: "Muito Bom",
      positiva: true,
      situacao: "POS"
    )
    assert_equal "MB", evaluation.avaliacao
    assert_equal "Muito Bom", evaluation.avaliacaodescricao
    assert evaluation.positiva
    assert_equal "POS", evaluation.situacao
  end

  test "default final is false" do
    evaluation = Evaluation.create!(school_year: @school_year, subject: @subject, evaluation_type: @eval_type, idavaliacao: 1)
    assert_not evaluation.final
  end
end
