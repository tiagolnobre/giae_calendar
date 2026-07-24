require "test_helper"

class EvaluationTypeTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @school_year = SchoolYear.create!(user: @user, label: "2025/2026")
  end

  test "should be valid with required attributes" do
    eval_type = EvaluationType.new(school_year: @school_year, idtipoavaliacao: 1, sigla: "1P", descricao: "1st Period")
    assert eval_type.valid?
  end

  test "belongs to school_year" do
    eval_type = @school_year.evaluation_types.create!(idtipoavaliacao: 1, sigla: "1P", descricao: "1st Period")
    assert_equal @school_year, eval_type.school_year
  end

  test "has many evaluations" do
    eval_type = @school_year.evaluation_types.create!(idtipoavaliacao: 1, sigla: "1P", descricao: "1st Period")
    subject = @school_year.subjects.create!(idmatriculadisciplina: 1, sigla: "PORT", descricao: "Português")
    evaluation = eval_type.evaluations.create!(school_year: @school_year, subject: subject, idavaliacao: 1)
    assert_includes eval_type.evaluations, evaluation
  end

  test "idtipoavaliacao should be unique per school_year" do
    @school_year.evaluation_types.create!(idtipoavaliacao: 1, sigla: "1P", descricao: "1st Period")
    duplicate = EvaluationType.new(school_year: @school_year, idtipoavaliacao: 1, sigla: "2P")
    assert_not duplicate.valid?
  end

  test "same idtipoavaliacao allowed for different school_years" do
    @school_year.evaluation_types.create!(idtipoavaliacao: 1, sigla: "1P")
    other_sy = SchoolYear.create!(user: @user, label: "2024/2025")
    other = EvaluationType.new(school_year: other_sy, idtipoavaliacao: 1, sigla: "1P")
    assert other.valid?
  end
end
