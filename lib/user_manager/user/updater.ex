defmodule UserManager.User.Updater do
  import Ecto.Query
  require Logger

  alias UserManager.Repo
  alias UserManager.User

  @batch_size 500
  @max_update_point 100
  @update_max_threads 8

  @spec update_all_points() :: {table_size :: integer(), num_batches :: integer(), exec_time :: integer()}
  def update_all_points do
    start_time = DateTime.utc_now()
    Logger.info("Starting update at: #{start_time}")
    {num_batches, table_size} = count_number_of_batches()

    do_update(num_batches, table_size)
    end_time = DateTime.utc_now()
    exec_time = DateTime.diff(end_time, start_time, :second)
    Logger.info("Finishing update at: #{end_time}")

    log_execution_result(table_size, num_batches, exec_time)
    {table_size, num_batches, exec_time}
  end

  defp count_number_of_batches do
    table_size = Repo.aggregate(User, :count, :id)

    num_batches =
      (table_size / @batch_size)
      |> Float.ceil(0)
      |> trunc()

    {num_batches, table_size}
  end

  defp do_update(_, 0 = _table_size), do: :noop

  defp do_update(num_batches, _) do
    0..(num_batches - 1)
    |> Enum.chunk_every(@update_max_threads)
    |> Enum.map(fn batches ->
      Task.async_stream(
        batches,
        &insert_batch_in_transaction/1,
        max_concurrency: @update_max_threads
      )
      |> Enum.to_list()
    end)
  end

  defp insert_batch_in_transaction(batch) do
    Repo.transaction(fn ->
      insert_batch(batch)
    end)
  end

  defp insert_batch(batch_num) do
    update_sql = create_multi_line_update(batch_num)

    Repo.insert_all(User, update_sql, conflict_target: :id, on_conflict: {:replace, [:points, :updated_at]})
  end

  defp create_multi_line_update(batch_num) do
    offset = batch_num * @batch_size

    Repo.stream(from u in User, limit: @batch_size, offset: ^offset)
    |> Task.async_stream(&update_points_and_prepare_data_to_update/1, max_concurrency: 4)
    |> Enum.map(fn {:ok, updated_user} -> updated_user end)
  end

  defp update_points_and_prepare_data_to_update(user) do
    new_points = user.points + generate_random_point_from_zero_to_max(@max_update_point)

    user
    |> Map.put(:points, new_points)
    |> Map.put(:updated_at, NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second))
    |> Map.from_struct()
    |> Map.drop([:__meta__])
  end

  defp generate_random_point_from_zero_to_max(max) do
    :rand.uniform(_range = max + 1) - 1
  end

  defp log_execution_result(table_size, num_batches, exec_time) do
    log = """
    Total registries: #{table_size}\n\
    Number of batches: #{num_batches}\n\
    Total time: #{exec_time}s\
    """

    Logger.info(log)
  end
end
