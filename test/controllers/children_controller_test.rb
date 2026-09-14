require "test_helper"

class ChildrenControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!
  end

  test "index shows children for current user" do
    get children_path
    assert_response :success
    assert_select "h1", I18n.t("children.title")
    assert_match children(:one).display_name, response.body
  end

  test "index marks current child" do
    get children_path
    assert_response :success
    assert_match I18n.t("children.current"), response.body
  end

  test "index redirects to sign_in when not authenticated" do
    delete sign_out_path
    get children_path
    assert_redirected_to %r{/sign_in}
  end

  test "new renders the form" do
    get new_child_path
    assert_response :success
    assert_select "form"
  end

  test "create adds a child and switches to it" do
    assert_difference("Child.count", 1) do
      post children_path, params: {
        child: {
          giae_username: "newuser",
          giae_password: "newpass"
        }
      }
    end

    assert_redirected_to children_path(locale: I18n.locale)
    assert_equal I18n.t("children.created"), flash[:notice]

    child = @user.children.last
    assert_equal "newuser", child.giae_username
    assert_equal child.id, session[:current_child_id]

    get calendar_path
    assert_response :success
  end

  test "create with invalid data does not add child" do
    assert_no_difference("Child.count") do
      post children_path, params: {
        child: {
          giae_username: "",
          giae_password: "pass"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "edit renders the form for own child" do
    get edit_child_path(children(:one))
    assert_response :success
  end

  test "edit is forbidden for another user's child" do
    get edit_child_path(children(:two))
    assert_response :not_found
  end

  test "update changes child credentials" do
    patch child_path(children(:one)), params: {
      child: {
        giae_username: "updateduser",
        giae_password: "updatedpass",
        giae_school_code: "123456"
      }
    }

    assert_redirected_to children_path(locale: I18n.locale)
    assert_equal I18n.t("children.updated"), flash[:notice]

    children(:one).reload
    assert_equal "updateduser", children(:one).giae_username
    assert_equal "123456", children(:one).giae_school_code
  end

  test "update with invalid data is unprocessable" do
    patch child_path(children(:one)), params: {
      child: {
        giae_username: ""
      }
    }

    assert_response :unprocessable_entity
  end

  test "update is forbidden for another user's child" do
    patch child_path(children(:two)), params: {
      child: { giae_username: "hacker" }
    }
    assert_response :not_found
  end

  test "destroy removes child and their data" do
    assert_difference("Child.count", -1) do
      assert_difference("MealTicket.count", -1) do
        assert_difference("GiaeSession.count", -3) do
          delete child_path(children(:one))
        end
      end
    end

    assert_redirected_to children_path(locale: I18n.locale)
    assert_equal I18n.t("children.deleted"), flash[:notice]
  end

  test "destroy is forbidden for another user's child" do
    assert_no_difference("Child.count") do
      delete child_path(children(:two))
    end
    assert_response :not_found
  end

  test "select switches the current child" do
    second_child = @user.children.create!(
      giae_username: "second",
      giae_password: "secondpass"
    )

    post select_child_path(second_child), headers: { "Referer" => calendar_path }
    assert_redirected_to calendar_path
    assert_equal I18n.t("children.selected", name: second_child.display_name), flash[:notice]
    assert_equal second_child.id, session[:current_child_id]

    get calendar_path
    assert_response :success
  end

  test "select falls back to calendar without referer" do
    post select_child_path(children(:one))
    assert_redirected_to calendar_path(locale: I18n.locale)
  end

  test "select is forbidden for another user's child" do
    post select_child_path(children(:two))
    assert_response :not_found
  end

  test "index shows empty state when no children" do
    delete sign_out_path
    user = User.create!(
      email: "nochildren@example.com",
      password: "password123",
      password_confirmation: "password123",
      children: []
    )
    post sign_in_path, params: { email: user.email, password: "password123" }
    follow_redirect!

    get children_path
    assert_response :success
    assert_match /any children yet/, response.body
  end
end