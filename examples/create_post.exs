# Creates a draft and publishes it.
#
#   FOPOST_API_KEY=fp_... elixir examples/create_post.exs "Hello from Elixir"
#
# From a checkout of this repository, this works too:
#
#   FOPOST_API_KEY=fp_... mix run examples/create_post.exs "Hello from Elixir"
#
# Publishing answers when delivery is queued, not when the post is live, so the script
# polls the deliveries once at the end to show where each account got to.

if not Code.ensure_loaded?(FoPost) do
  Mix.install([{:fopost, "~> 0.1"}])
end

text =
  case System.argv() do
    [text | _rest] -> text
    [] -> "Hello from the FoPost Elixir SDK"
  end

client = FoPost.new()

workspace =
  case FoPost.Workspaces.list(client) do
    {:ok, [workspace | _rest]} ->
      workspace

    {:ok, []} ->
      raise "This key cannot reach any workspace. Create one in the FoPost dashboard."

    {:error, error} ->
      raise Exception.message(error)
  end

IO.puts("Workspace: #{workspace.name} (#{workspace.id})")

accounts =
  case FoPost.Accounts.list(client, workspace_id: workspace.id) do
    {:ok, []} -> raise "No connected accounts. Connect one in the FoPost dashboard."
    {:ok, accounts} -> accounts
    {:error, error} -> raise Exception.message(error)
  end

for account <- accounts do
  IO.puts("  #{account.platform}: @#{account.username} (#{account.health_status})")
end

post =
  FoPost.Posts.create!(client,
    workspace_id: workspace.id,
    accounts: Enum.map(accounts, & &1.id),
    content: text,
    status: "draft"
  )

IO.puts("Created draft #{post.id}")

# Check every target platform before anything goes out.
preflight = FoPost.Posts.preflight!(client, post.id)

for account <- preflight.accounts, account.issues != [] do
  IO.puts("  #{account.platform} is not ready: #{Enum.join(account.issues, ", ")}")
end

if preflight.ready do
  result = FoPost.Posts.publish!(client, post.id)
  IO.puts("Publishing: #{result.post_status}")

  for delivery <- FoPost.Posts.deliveries!(client, post.id) do
    IO.puts("  #{delivery.platform || delivery.account_id}: #{delivery.status}")
  end
else
  IO.puts("Left as a draft — preflight found blockers.")
end
