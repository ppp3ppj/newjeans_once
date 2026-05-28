defmodule NewjeansOnceWeb.BoardLiveTest do
  use NewjeansOnceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias NewjeansOnce.Board

  # Shared DB sandbox (async: false) means all LiveView processes can access
  # the repo without needing explicit Sandbox.allow/3 calls.

  defp create_post(attrs \\ %{}) do
    default = %{
      "author" => "TestBunny",
      "title" => "Test Post",
      "description" => "Hello from test"
    }

    {:ok, msg} = Board.create_message(Map.merge(default, attrs))
    msg
  end

  # ── Mount ───────────────────────────────────────────────────────────────

  describe "mount" do
    test "renders FAN WALL heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "FAN WALL"
    end

    test "shows existing posts on load", %{conn: conn} do
      post = create_post(%{"title" => "MINJI SUPREMACY"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ post.title
    end

    test "shows post count in layout", %{conn: conn} do
      create_post(%{"title" => "First"})
      create_post(%{"title" => "Second"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "2"
    end
  end

  # ── Typing indicator ─────────────────────────────────────────────────────

  describe "typing indicator" do
    test "opening new post modal shows typing count to all connected users", %{conn: conn} do
      {:ok, view_a, _} = live(conn, ~p"/")
      {:ok, view_b, _} = live(conn, ~p"/")

      view_a |> element("button[phx-click='open_new_modal']") |> render_click()

      assert render(view_b) =~ "BUNNY WRITING"
    end

    test "closing new post modal clears typing indicator for all users", %{conn: conn} do
      {:ok, view_a, _} = live(conn, ~p"/")
      {:ok, view_b, _} = live(conn, ~p"/")

      view_a |> element("button[phx-click='open_new_modal']") |> render_click()
      # Use the Cancel button inside the form — the ✕ button shares the same phx-click
      view_a |> element("button[phx-click='close_new_modal']", "Cancel") |> render_click()

      refute render(view_b) =~ "BUNNY WRITING"
    end
  end

  # ── Creating a post ──────────────────────────────────────────────────────

  describe "creating a post" do
    test "new post appears in all connected clients streams", %{conn: conn} do
      {:ok, view_a, _} = live(conn, ~p"/")
      {:ok, view_b, _} = live(conn, ~p"/")

      view_a |> element("button[phx-click='open_new_modal']") |> render_click()

      view_a
      |> form("#new-message-form", message: %{title: "HANNI RULES", description: "yes"})
      |> render_submit()

      assert render(view_b) =~ "HANNI RULES"
    end

    test "new post toast is broadcast to all other users", %{conn: conn} do
      {:ok, view_a, _} = live(conn, ~p"/")
      {:ok, view_b, _} = live(conn, ~p"/")

      view_a |> element("button[phx-click='open_new_modal']") |> render_click()

      view_a
      |> form("#new-message-form", message: %{title: "Test Toast", description: "hello"})
      |> render_submit()

      assert render(view_b) =~ "NEW POST BY"
    end

    test "confetti push_event is sent only to the poster", %{conn: conn} do
      {:ok, view_poster, _} = live(conn, ~p"/")
      {:ok, view_other, _} = live(conn, ~p"/")

      view_poster |> element("button[phx-click='open_new_modal']") |> render_click()

      view_poster
      |> form("#new-message-form", message: %{title: "CONFETTI TEST", description: "boom"})
      |> render_submit()

      # Poster's socket receives confetti
      assert_push_event(view_poster, "confetti", %{})

      # Other user's socket does NOT receive confetti (no message with that ref)
      refute_push_event(view_other, "confetti", %{})
    end
  end

  # ── Reactions ────────────────────────────────────────────────────────────

  describe "reactions" do
    test "clicking a reaction sends updated counts push_event back to the clicker", %{
      conn: conn
    } do
      post = create_post()
      post_id = post.id
      {:ok, view, _} = live(conn, ~p"/")

      view |> element("#rxn-#{post_id}-star") |> render_click()

      assert_push_event(view, "reactions:updated", %{post_id: ^post_id, counts: %{star: 1}})
    end

    test "reaction update is broadcast via push_event to all connected users", %{conn: conn} do
      post = create_post()
      post_id = post.id
      {:ok, view_a, _} = live(conn, ~p"/")
      {:ok, view_b, _} = live(conn, ~p"/")

      view_a |> element("#rxn-#{post_id}-bunny") |> render_click()

      assert_push_event(view_b, "reactions:updated", %{post_id: ^post_id, counts: %{bunny: 1}})
    end

    test "multiple reaction clicks accumulate counts", %{conn: conn} do
      post = create_post()
      {:ok, view, _} = live(conn, ~p"/")

      view |> element("#rxn-#{post.id}-cat") |> render_click()
      assert_push_event(view, "reactions:updated", %{counts: %{cat: 1}})

      view |> element("#rxn-#{post.id}-cat") |> render_click()
      assert_push_event(view, "reactions:updated", %{counts: %{cat: 2}})
    end
  end

  # ── Under review indicator ───────────────────────────────────────────────
  #
  # Phoenix.LiveViewTest's render_click consumes PubSub messages delivered to
  # the test process during event processing, making assert_receive on the
  # reviewing topic unreliable. We test observable outcomes instead:
  # the delete modal (outer template) and stream deletion (cross-view).

  describe "under review indicator" do
    test "confirm_delete opens the delete modal with post details", %{conn: conn} do
      post = create_post(%{"title" => "Marked For Death"})
      {:ok, view, _} = live(conn, ~p"/")

      view
      |> element("button[phx-click='confirm_delete'][phx-value-id='#{post.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "// DELETE POST?"
      assert html =~ "Marked For Death"
    end

    test "cancel_delete closes the delete modal", %{conn: conn} do
      post = create_post()
      {:ok, view, _} = live(conn, ~p"/")

      view
      |> element("button[phx-click='confirm_delete'][phx-value-id='#{post.id}']")
      |> render_click()

      view |> element("button[phx-click='cancel_delete']") |> render_click()

      refute render(view) =~ "// DELETE POST?"
    end

    test "confirming delete removes card from all clients streams", %{conn: conn} do
      post = create_post(%{"title" => "Gone Forever"})
      {:ok, view_a, _} = live(conn, ~p"/")
      {:ok, view_b, _} = live(conn, ~p"/")

      view_a
      |> element("button[phx-click='confirm_delete'][phx-value-id='#{post.id}']")
      |> render_click()

      view_a |> element("button[phx-click='delete']") |> render_click()

      refute render(view_b) =~ "Gone Forever"
    end

    test "confirming delete closes the modal on the actor's view", %{conn: conn} do
      post = create_post()
      {:ok, view, _} = live(conn, ~p"/")

      view
      |> element("button[phx-click='confirm_delete'][phx-value-id='#{post.id}']")
      |> render_click()

      view |> element("button[phx-click='delete']") |> render_click()

      refute render(view) =~ "// DELETE POST?"
    end
  end

  # ── Editing ──────────────────────────────────────────────────────────────
  #
  # Stream items don't re-render on outer assign changes — the EDITING badge on
  # the card requires stream_insert to be called. We test the edit modal (outer
  # template) which reliably reflects the editing_id assign.

  describe "editing" do
    test "clicking EDIT opens the edit modal", %{conn: conn} do
      post = create_post(%{"title" => "Edit Me Please"})
      {:ok, view, _} = live(conn, ~p"/")

      view |> element("button[phx-click='edit'][phx-value-id='#{post.id}']") |> render_click()

      assert render(view) =~ "// EDIT POST"
    end

    test "cancelling edit closes the edit modal", %{conn: conn} do
      post = create_post(%{"title" => "Edit And Cancel"})
      {:ok, view, _} = live(conn, ~p"/")

      view |> element("button[phx-click='edit'][phx-value-id='#{post.id}']") |> render_click()
      view |> element("button[phx-click='cancel_edit']", "Cancel") |> render_click()

      refute render(view) =~ "// EDIT POST"
    end

    test "saving edit updates the post content for all users", %{conn: conn} do
      post = create_post(%{"title" => "Old Title"})
      {:ok, view_a, _} = live(conn, ~p"/")
      {:ok, view_b, _} = live(conn, ~p"/")

      view_a |> element("button[phx-click='edit'][phx-value-id='#{post.id}']") |> render_click()

      view_a
      |> form("#edit-message-form",
        message: %{title: "New Title", description: post.description}
      )
      |> render_submit()

      assert render(view_b) =~ "New Title"
    end
  end

  # ── Deleting ─────────────────────────────────────────────────────────────

  describe "deleting a post" do
    test "deleted post disappears from all clients", %{conn: conn} do
      post = create_post(%{"title" => "Temporary Post"})
      {:ok, view_a, _} = live(conn, ~p"/")
      {:ok, view_b, _} = live(conn, ~p"/")

      view_a
      |> element("button[phx-click='confirm_delete'][phx-value-id='#{post.id}']")
      |> render_click()

      view_a |> element("button[phx-click='delete']") |> render_click()

      refute render(view_a) =~ "Temporary Post"
      refute render(view_b) =~ "Temporary Post"
    end

    test "post count decrements after delete", %{conn: conn} do
      post = create_post()
      {:ok, view, html} = live(conn, ~p"/")

      initial_count = Board.count_messages()
      assert html =~ to_string(initial_count)

      view
      |> element("button[phx-click='confirm_delete'][phx-value-id='#{post.id}']")
      |> render_click()

      view |> element("button[phx-click='delete']") |> render_click()

      assert render(view) =~ to_string(initial_count - 1)
    end
  end

  # ── Post of the day ──────────────────────────────────────────────────────────

  describe "post of the day" do
    test "post with first reaction gets gold bar", %{conn: conn} do
      post = create_post()
      post_id = post.id
      {:ok, view, _} = live(conn, ~p"/")

      view |> element("#rxn-#{post_id}-star") |> render_click()
      assert_push_event(view, "reactions:updated", %{post_id: ^post_id})

      assert render(view) =~ "bg-[#ffd700]"
    end

    test "post with more reactions displaces previous potd and moves to top", %{conn: conn} do
      post_a = create_post(%{"title" => "Alpha"})
      post_b = create_post(%{"title" => "Beta"})
      a_id = post_a.id
      b_id = post_b.id
      {:ok, view, _} = live(conn, ~p"/")

      view |> element("#rxn-#{a_id}-star") |> render_click()
      assert_push_event(view, "reactions:updated", %{post_id: ^a_id})

      view |> element("#rxn-#{b_id}-star") |> render_click()
      assert_push_event(view, "reactions:updated", %{post_id: ^b_id})
      view |> element("#rxn-#{b_id}-cat") |> render_click()
      assert_push_event(view, "reactions:updated", %{post_id: ^b_id})

      html = render(view)
      assert html =~ "bg-[#ffd700]"
      assert :binary.match(html, "Beta") |> elem(0) < :binary.match(html, "Alpha") |> elem(0)
    end

    test "deleting the potd post clears the gold bar", %{conn: conn} do
      post = create_post()
      post_id = post.id
      {:ok, view, _} = live(conn, ~p"/")

      view |> element("#rxn-#{post_id}-star") |> render_click()
      assert_push_event(view, "reactions:updated", %{post_id: ^post_id})
      assert render(view) =~ "bg-[#ffd700]"

      view |> element("button[phx-click='confirm_delete'][phx-value-id='#{post_id}']") |> render_click()
      view |> element("button[phx-click='delete']") |> render_click()

      refute render(view) =~ "bg-[#ffd700]"
    end
  end

  # ── Guest name color ─────────────────────────────────────────────────────────

  describe "guest name color" do
    test "connected user's name is rendered with an hsl color", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "hsl("
    end

    test "guest color is included in the posting-as badge", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/")
      view |> element("button[phx-click='open_new_modal']") |> render_click()
      assert render(view) =~ "hsl("
    end
  end

  # ── Confetti milestone ───────────────────────────────────────────────────────

  describe "confetti on reaction milestone" do
    test "confetti fires when post reaches 10 total reactions", %{conn: conn} do
      post = create_post()
      post_id = post.id
      {:ok, view, _} = live(conn, ~p"/")

      for _ <- 1..10 do
        view |> element("#rxn-#{post_id}-star") |> render_click()
      end

      assert_push_event(view, "confetti", %{})
    end

    test "confetti fires for all connected users at the milestone", %{conn: conn} do
      post = create_post()
      post_id = post.id
      {:ok, view_a, _} = live(conn, ~p"/")
      {:ok, view_b, _} = live(conn, ~p"/")

      for _ <- 1..10 do
        view_a |> element("#rxn-#{post_id}-star") |> render_click()
      end

      assert_push_event(view_a, "confetti", %{})
      assert_push_event(view_b, "confetti", %{})
    end

    test "confetti does not fire before 10 reactions", %{conn: conn} do
      post = create_post()
      post_id = post.id
      {:ok, view, _} = live(conn, ~p"/")

      for _ <- 1..9 do
        view |> element("#rxn-#{post_id}-star") |> render_click()
      end

      refute_push_event(view, "confetti", %{})
    end
  end
end
