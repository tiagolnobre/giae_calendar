require "test_helper"

class SchoolYearTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @child = children(:one)
    @school_year = SchoolYear.new(child: @child, user: @user, label: "2025/2026")
  end

  test "should be valid with required attributes" do
    assert @school_year.valid?
  end

  test "label should be present" do
    @school_year.label = ""
    assert_not @school_year.valid?
  end

  test "label should be unique per child" do
    @school_year.save!
    duplicate = SchoolYear.new(child: @child, user: @user, label: "2025/2026")
    assert_not duplicate.valid?
  end

  test "same label allowed for different children" do
    @school_year.save!
    other = SchoolYear.new(child: children(:two), user: users(:two), label: "2025/2026")
    assert other.valid?
  end

  test "label_from_date for September to December" do
    assert_equal "2025/2026", SchoolYear.label_from_date(Date.parse("2025-09-01"))
    assert_equal "2025/2026", SchoolYear.label_from_date(Date.parse("2025-12-31"))
  end

  test "label_from_date for January to August" do
    assert_equal "2025/2026", SchoolYear.label_from_date(Date.parse("2026-01-01"))
    assert_equal "2025/2026", SchoolYear.label_from_date(Date.parse("2026-08-31"))
  end

  test "label_from_date edge cases" do
    assert_equal "2025/2026", SchoolYear.label_from_date(Date.parse("2025-09-01"))
    assert_equal "2024/2025", SchoolYear.label_from_date(Date.parse("2025-08-31"))
  end

  test "destroy cascades to subjects" do
    @school_year.save!
    @school_year.subjects.create!(idmatriculadisciplina: 1, sigla: "TST", descricao: "Test")
    assert_difference "Subject.count", -1 do
      @school_year.destroy
    end
  end

  test "destroy cascades to evaluation_types" do
    @school_year.save!
    @school_year.evaluation_types.create!(idtipoavaliacao: 1, sigla: "1P", descricao: "1st Period")
    assert_difference "EvaluationType.count", -1 do
      @school_year.destroy
    end
  end

  test "destroy cascades to evaluations" do
    @school_year.save!
    subject = @school_year.subjects.create!(idmatriculadisciplina: 1, sigla: "TST", descricao: "Test")
    eval_type = @school_year.evaluation_types.create!(idtipoavaliacao: 1, sigla: "1P", descricao: "1st Period")
    @school_year.evaluations.create!(subject: subject, evaluation_type: eval_type, idavaliacao: 1)
    assert_difference "Evaluation.count", -1 do
      @school_year.destroy
    end
  end

  test "destroy cascades to final_evaluations" do
    @school_year.save!
    @school_year.final_evaluations.create!(descricaorfa: "Approved")
    assert_difference "FinalEvaluation.count", -1 do
      @school_year.destroy
    end
  end

  test "belongs_to user" do
    @school_year.save!
    assert_equal @user, @school_year.user
  end
end
