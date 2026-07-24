require "test_helper"

class SubjectTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @school_year = SchoolYear.create!(user: @user, label: "2025/2026")
  end

  test "should be valid with required attributes" do
    subject = Subject.new(school_year: @school_year, idmatriculadisciplina: 1, sigla: "PORT", descricao: "Português")
    assert subject.valid?
  end

  test "belongs to school_year" do
    subject = @school_year.subjects.create!(idmatriculadisciplina: 1, sigla: "PORT", descricao: "Português")
    assert_equal @school_year, subject.school_year
  end

  test "has many evaluations" do
    subject = @school_year.subjects.create!(idmatriculadisciplina: 1, sigla: "PORT", descricao: "Português")
    eval_type = @school_year.evaluation_types.create!(idtipoavaliacao: 1, sigla: "1P", descricao: "1st Period")
    evaluation = subject.evaluations.create!(school_year: @school_year, evaluation_type: eval_type, idavaliacao: 1)
    assert_includes subject.evaluations, evaluation
  end

  test "destroy cascades to evaluations" do
    subject = @school_year.subjects.create!(idmatriculadisciplina: 1, sigla: "PORT", descricao: "Português")
    eval_type = @school_year.evaluation_types.create!(idtipoavaliacao: 1, sigla: "1P", descricao: "1st Period")
    subject.evaluations.create!(school_year: @school_year, evaluation_type: eval_type, idavaliacao: 1)
    assert_difference "Evaluation.count", -1 do
      subject.destroy
    end
  end

  test "idmatriculadisciplina should be unique per school_year" do
    @school_year.subjects.create!(idmatriculadisciplina: 1, sigla: "PORT", descricao: "Português")
    duplicate = Subject.new(school_year: @school_year, idmatriculadisciplina: 1, sigla: "MAT", descricao: "Matemática")
    assert_not duplicate.valid?
  end
end
