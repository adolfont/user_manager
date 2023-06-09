defmodule UserManager.UserTest do
  use UserManager.DataCase
  alias UserManager.Factories.UserFactory
  alias UserManager.Users

  describe "fetch_user_by_id/1" do
    test "when user exists, should return {:ok, user} tuple" do
      user = UserFactory.insert(:user)

      assert Users.fetch_user_by_id(user.id) == {:ok, user}
    end

    test "when user does not exist, should return {:error, detail} tuple" do
      fake_id = 1

      assert Users.fetch_user_by_id(fake_id) == {:error, "User not found given for ID `#{fake_id}`"}
    end
  end

  describe "find_users_by_min_point/2" do
    test "when user exists but min_point above user point, should not find any user" do
      UserFactory.insert(:user, points: 10)
      min_point = 11

      assert Users.find_users_by_min_point(min_point, _quantity = 1) == []
    end

    test "when user exists and min_point below user point, should return user in a list" do
      user = UserFactory.insert(:user, points: 10)
      min_point = 9

      assert_users_returned_by_min_points([user], 1, Users.find_users_by_min_point(min_point, _quantity = 1))
    end

    test "when user exists and min_point equals user point, should not find any user" do
      UserFactory.insert(:user, points: 10)
      min_point = 10

      assert Users.find_users_by_min_point(min_point, _quantity = 1) == []
    end

    test "when multiple users exist and multiple users are above min_point, should return users above min_point in the size limit requested" do
      user_1 = UserFactory.insert(:user, points: 10)
      user_2 = UserFactory.insert(:user, points: 20)
      user_3 = UserFactory.insert(:user, points: 30)
      user_4 = UserFactory.insert(:user, points: 40)

      assert_users_returned_by_min_points([user_3], 1, Users.find_users_by_min_point(_min_point = 25, _quantity = 1))

      assert_users_returned_by_min_points(
        [user_3, user_4],
        2,
        Users.find_users_by_min_point(_min_point = 25, _quantity = 2)
      )

      assert_users_returned_by_min_points(
        [user_1, user_2, user_3],
        3,
        Users.find_users_by_min_point(_min_point = 5, _quantity = 3)
      )

      assert_users_returned_by_min_points([user_4], 1, Users.find_users_by_min_point(_min_point = 35, _quantity = 20))
    end
  end

  describe "create_user/1" do
    test "when user does not exist, should return {:ok, user} tuple" do
      {:ok, user} = Users.create_user(%{points: 10})

      assert Users.fetch_user_by_id(user.id) == {:ok, user}
    end
  end

  describe "update_user/1" do
    test "when user exists, should return {:ok, updated_user} tuple" do
      user = UserFactory.insert(:user, points: 5)

      Users.update_user(user, %{points: 10})
      {:ok, updated_user} = Users.fetch_user_by_id(user.id)
      assert %{points: 10} = updated_user
    end

    test "when user does not exist, should return {:error, detail} tuple" do
      fake_id = 9999
      fake_user = UserFactory.build(:user, id: fake_id, points: 5)

      assert {:error, _} = Users.update_user(fake_user, %{points: 10})
    end
  end

  defp assert_users_returned_by_min_points(expected_users, expected_user_count, response) do
    assert Enum.count(response) == expected_user_count

    response
    |> Enum.zip(expected_users)
    |> Enum.map(fn {response_line, expected_user} ->
      assert response_line.id == expected_user.id
      assert response_line.points == expected_user.points
    end)
  end
end
