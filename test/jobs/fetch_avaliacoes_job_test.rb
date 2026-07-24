require "test_helper"

class FetchAvaliacoesJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @job = FetchAvaliacoesJob.new
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "job is enqueued with correct queue" do
    assert_equal "default", FetchAvaliacoesJob.queue_name
  end

  test "perform creates school_year with evaluations" do
    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_avaliacoes).returns({
      tiposavaliacoes: [
        { "idtipoavaliacao" => 1, "descricao" => "Final 1.º Período", "sigla" => "1P", "datainicio" => "2025-09-11" },
        { "idtipoavaliacao" => 2, "descricao" => "Final 2.º Período", "sigla" => "2P", "datainicio" => "2026-01-05" }
      ],
      disciplinas: [
        { "idmatriculadisciplina" => 114650, "iddisciplina" => 277, "sigla" => "PORT", "descricao" => "Português", "ordem" => 1 },
        { "idmatriculadisciplina" => 114651, "iddisciplina" => 533, "sigla" => "MAT", "descricao" => "Matemática", "ordem" => 2 }
      ],
      avaliacoes: [
        {
          "idmatriculadisciplina" => 114650, "idtipoavaliacao" => 1,
          "idavaliacao" => 366151, "data" => "2025-12-19",
          "avaliacao" => "MB", "avaliacaodescricao" => "Muito Bom",
          "positiva" => true, "situacao" => "POS"
        }
      ],
      avaliacaofinal: [
        { "idmatricula" => 12564, "descricaorfa" => "Transitou", "positivorfa" => true }
      ]
    })

    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).yields(mock_scraper)
    GiaeSessionManager.stubs(:new).with(@user).returns(mock_session_manager)

    assert_difference -> { SchoolYear.count } => 1,
                      -> { Subject.count } => 2,
                      -> { EvaluationType.count } => 2,
                      -> { Evaluation.count } => 1,
                      -> { FinalEvaluation.count } => 1 do
      @job.perform(@user)
    end

    school_year = SchoolYear.last
    assert_equal "2025/2026", school_year.label
    assert_equal @user, school_year.user
    assert_equal 2, school_year.subjects.count
    assert_equal 2, school_year.evaluation_types.count
    assert_equal 1, school_year.evaluations.count
    assert_equal 1, school_year.final_evaluations.count
  end

  test "perform replaces existing school_year data" do
    school_year = SchoolYear.create!(user: @user, label: "2025/2026")
    school_year.subjects.create!(idmatriculadisciplina: 1, sigla: "OLD", descricao: "Old Subject")

    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_avaliacoes).returns({
      tiposavaliacoes: [
        { "idtipoavaliacao" => 1, "descricao" => "1P", "sigla" => "1P", "datainicio" => "2025-09-11" }
      ],
      disciplinas: [
        { "idmatriculadisciplina" => 2, "iddisciplina" => 1, "sigla" => "NEW", "descricao" => "New Subject", "ordem" => 1 }
      ],
      avaliacoes: [],
      avaliacaofinal: []
    })

    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).yields(mock_scraper)
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    assert_no_difference "SchoolYear.count" do
      @job.perform(@user)
    end

    school_year.reload
    assert_equal 1, school_year.subjects.count
    assert_equal "NEW", school_year.subjects.first.sigla
  end

  test "perform handles integer user id" do
    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_avaliacoes).returns({
      tiposavaliacoes: [
        { "idtipoavaliacao" => 1, "descricao" => "1P", "sigla" => "1P", "datainicio" => "2025-09-11" }
      ],
      disciplinas: [
        { "idmatriculadisciplina" => 1, "iddisciplina" => 1, "sigla" => "PORT", "descricao" => "Português", "ordem" => 1 }
      ],
      avaliacoes: [],
      avaliacaofinal: []
    })

    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).yields(mock_scraper)
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    assert_difference "SchoolYear.count", 1 do
      @job.perform(@user.id)
    end
  end

  test "perform handles empty data gracefully" do
    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_avaliacoes).returns({
      tiposavaliacoes: [],
      disciplinas: [],
      avaliacoes: [],
      avaliacaofinal: []
    })

    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).yields(mock_scraper)
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    assert_no_difference -> { SchoolYear.count } do
      assert_no_difference -> { Subject.count } do
        assert_no_difference -> { EvaluationType.count } do
          assert_no_difference -> { Evaluation.count } do
            @job.perform(@user)
          end
        end
      end
    end
  end

  test "perform re-raises SessionUnavailable error" do
    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).raises(GiaeSessionManager::SessionUnavailable, "Session expired")
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    assert_raises(GiaeSessionManager::SessionUnavailable) do
      @job.perform(@user)
    end
  end

  test "perform creates school_year label from earliest evaluation type date" do
    mock_scraper = mock("scraper")
    mock_scraper.stubs(:fetch_avaliacoes).returns({
      tiposavaliacoes: [
        { "idtipoavaliacao" => 1, "descricao" => "1P", "sigla" => "1P", "datainicio" => "2026-01-05" }
      ],
      disciplinas: [
        { "idmatriculadisciplina" => 1, "iddisciplina" => 1, "sigla" => "PORT", "descricao" => "Português", "ordem" => 1 }
      ],
      avaliacoes: [],
      avaliacaofinal: []
    })

    mock_session_manager = mock("session_manager")
    mock_session_manager.stubs(:with_active_session).yields(mock_scraper)
    GiaeSessionManager.stubs(:new).returns(mock_session_manager)

    @job.perform(@user)
    assert_equal "2025/2026", SchoolYear.last.label
  end
end
