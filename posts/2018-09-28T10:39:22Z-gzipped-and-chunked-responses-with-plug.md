---
%{
  title: "Gzipped and chunked responses with Plug",
  description: "How to send gzipped and chunked responses with plug",
  created_at: "2018-09-28T10:39:22.990905Z"
}
---
Here's a recent use-case I wanted to tackle: Getting large amounts of json data from an elixir web app.

### Assumptions

- We do not want to keep the data in memory because it can be very large, and there may be many
similar requests coming in.
- The data itself comes from some source we can stream from, like a database or AWS s3.

### Chunks

HTTP (1.1) has a very nice feature called [chunked transfer encoding](https://en.wikipedia.org/wiki/Chunked_transfer_encoding). This
allows us to send *chunks* to the client. A stream fits well with chunked transfers. And [plug](https://github.com/elixir-plug/plug) has great support for this.

```elixir
# Example code TODO:
# conn
# |> chunk_headers
# |> chunk_start_payload
# |> Stream from source
# |> chunks
# |> chunk_end_payload
```

### Gzip

Since the data we stream out may be very large, compressing it for clients that requests it makes sense to speed up the transfer.
The easiest thing would be to simply gather the data in-memory and then pop it out in one go with `:zlib.gzip(mydata)` and the correct http headers. But we just implemented chunking so that we don't have to keep the whole data in memory. So what to do? We can compress the chunks. This was not straigh forward to do and I'm still not sure that what I cooked up is a good approach. If you have suggestions on improving this I would love to hear about it!

#### Headers

Before getting to the individual chunks we first have to indicate to the client that we are going to send gzipped things.

```elixir
Plug.Conn.put_resp_header(conn, "content-encoding", "gzip")
```

### Test first

I knew exactly what outcome I wanted, but not quite how the implementation would look so I started with a test.

```elixir
test "should gzip json data if requested" do
  conn =
    build_conn()
    |> put_req_header("accept-encoding", "application/gzip")
    |> get("/data")

  assert conn.status == 200
  assert Enum.member?(conn.resp_headers, {"content-type", "application/json; charset=utf-8"})
  assert Enum.member?(conn.resp_headers, {"content-encoding", "gzip"})
  assert {:ok, _} = conn.resp_body |> :zlib.gunzip() |> Poison.decode()
end
```

### Attempt one

This boiled down to gzipping every chunk payload like so: `Plug.Conn.chunk(conn, :zlib.gzip(chunk_payload))`. This worked in my ExUnit tests,
and using `curl` but it did not work in any of the browsers I tried (Firefox, Safari, Chrome). In the browsers I either got the first chunk only, or a JSON parse error. Very interesting! This was surely a smell that my implementation was not correct.

It was not clear why the data was not understood by the browsers but this [thread on Stack Overflow](https://stackoverflow.com/questions/5280633/gzip-compression-of-chunked-encoding-response) made me suspect that it had to do with including the full gzip headers in every chunk. Here's what I think the first attempt's implementation meant: It output one full gzipped package per chunk that had to be unpacked individually instead of one large package that was fully assembled once the last chunk was sent.

### Attempt two

I did not know exactly how to proceed, but figured I should read up on the [erlang zlib](http://erlang.org/doc/man/zlib.html) documentation to see what's possible.

#### Getting to know erlang's `zlib`

The SO thread mentioned details on window bits and init functions. Is there something like that in the erlang implementation I can control?
Yes `zlib.deflateInit/6` has a `WindowBits` option, promising. `deflateInit` needs a zstream though, what's that? "A zlib stream, see [open/0](http://erlang.org/doc/man/zlib.html#open-0)." Hmmm okay time to play around in `iex`.

```elixir
z = :zlib.open()
:ok = :zlib.deflateInit(z, :default, :deflated, 31, 8, :default)
```

Fancy, and lots of magic parameters. All of them except `31` for the WindowBits are defaults for `deflateInit/6`.
This is a good start, we have a zstream and have configured it. At this point all I want to do is to compress some text,
and be able to uncompress it again.

```elixir
# deflate
# deflate :finish
# deflateEnd
```

With a bit of imagination we can see how this could fit together with the chunks; call deflate on the chunk_payload and send that. Will this approach pass the browser test?

#### Plugging it in

Awful title aside, here's how a module which wraps the zlib functionality could look like

```elixir
defmodule MyApp.ChunkCompressor do
  def init(%Plug.Conn{} = conn) do
    conn
    |> Plug.Conn.assign(gzip, gzip_requested?(conn)) # gzip_requested? return boolean based on accept-encoding header
    |> content_encoding()
    |> init_zstream()
  end

  def chunk(%Plug.Conn{assigns: %{gzip: false}} = conn, payload, _deflate_option) do
    Plug.Conn.chunk(conn, payload)
  end

  def chunk(%Plug.Conn{assigns: %{gzip: true, zstream: zstream}} = conn, payload, :sync) do
    compressed_payload = :zlib.deflate(zstream, payload, :sync)
    Plug.Conn.chunk(conn, compressed_payload)
  end

  def chunk(%Plug.Conn{assigns: %{gzip: true, zstream: zstream}} = conn, payload, :finish) do
    compressed_payload = :zlib.deflate(zstream, payload, :finish)
    :zlib.deflateEnd(zstream)
    Plug.Conn.chunk(conn, compressed_payload)
  end

  defp init_zstream(%Plug.Conn{assigns: %{gzip: false}} = conn), do: conn
  defp init_zstream(%Plug.Conn{assigns: %{gzip: true}} = conn) do
    with zstream <- :zlib.open(),
         :ok <- :zlib.deflateInit(zstream, :default, :deflated, 31, 8, :default) do
      Plug.Conn.assign(conn, :zstream, zstream)
    end
  end
end
```

Using this we can finally verify with a browser that we do get all the expected json. Celebration!

### Future

HTTP/2 does not support chunked transfer encoding (it even forbids it). I don't know how a solution would look like for HTTP/2, but maybe I'll write a follow-up if I get to experiment a bit.