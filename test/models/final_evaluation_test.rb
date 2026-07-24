require "test_helper"

class FinalEvaluationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @school_year = SchoolYear.create!(user: @user, label: "2025/2026")
  end

  test "should be valid with required associations" do
    final = FinalEvaluation.new(school_year: @school_year)
    assert final.valid?
  end

  test "belongs to school_year" do
    final = FinalEvaluation.create!(school_year: @school_year)
    assert_equal @school_year, final.school_year
  end

  test "stores final evaluation fields" do
    final = FinalEvaluation.create!(
      school_year: @school_year,
      idmatricula: 12564,
      descricaorfa: "Transitou",
      positivorfa: true,
      descricaorfc: nil,
      positivorfc: nil
    )
    assert_equal "Transitou", final.descricaorfa
    assert final.positivorfa
    assert_nil final.descricaorfc
  end

  test "only one final evaluation per school_year" do
    FinalEvaluation.create!(school_year: @school_year)
    duplicate = FinalEvaluation.new(school_year: @school_year)
    assert_not duplicate.valid?
  end
end
