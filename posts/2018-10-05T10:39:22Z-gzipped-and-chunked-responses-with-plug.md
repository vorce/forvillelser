---
%{
  title: "Experiment with gzipped and chunked HTTP responses with Plug",
  description: "How I discovered that gzipping the data for chunked transfer encoding didn't result in what I thought it would :)",
  created_at: "2018-10-05T10:39:22.990905Z"
}
---
Recently I wanted to add gzip support to an API endpoint which could give back very large amounts of JSON. Internally the API
gets data from a source where the size of the payload is not known upfront. To deliver the data it uses a HTTP (1.1) feature called
 [chunked transfer encoding](https://en.wikipedia.org/wiki/Chunked_transfer_encoding) with `Plug.Conn.chunk()`. After finishing the implementation I found some, to me, surprising results.


### Requirements

- We do not want to keep the data in memory because it can be very large, and there may be many
similar requests coming in.
- The data itself comes from some source we can stream from, like a database or AWS s3.
- Elixir implementation

### Hypothesis

Adding compression of the data using erlang's zlib will speed up the transfer iff the data size exceeds some threshold.

### Gzip

The easiest thing would be to simply gather the data in-memory and then pop it out in one go with `:zlib.gzip(mydata)` and the correct http headers. But we implemented chunking so that we don't have to keep the whole data in memory. So what to do? We can compress the chunks. This was not straigh forward to do and I'm still not sure that what I cooked up is the optimal way to do it.

#### Headers

Before getting to the individual chunks we first have to indicate to the client that we are going to send gzipped things.

```elixir
Plug.Conn.put_resp_header(conn, "content-encoding", "gzip")
```

Of course we should only do this if the client actually asked for compression -- ie has set the request header `Accept-Encoding` to `application/gzip` or `gzip, deflate`.

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

It was not clear why the data was not understood by the browsers but this [thread on Stack Overflow](https://stackoverflow.com/questions/5280633/gzip-compression-of-chunked-encoding-response) made me suspect that it had to do with including the full gzip headers in every chunk. The first attempt's implementation meant: It output one full gzipped "file" per chunk that had to be unpacked individually instead of one large "file" that was fully assembled once the last chunk was sent.

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
first = :zlib.deflate(z, "my first string")
second = :zlib.deflate(z, "my second string", :finish)
:zlib.deflateEnd(z)
:zlib.gunzip(first ++ second) # "my first stringmy second string"
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

And here's a phoenix controller using our ChunkCompressor:

```elixir
# ...

def data(conn, _params) do
  conn =
    conn
    |> put_resp_content_type("application/json")
    |> MyApp.ChunkCompressor.init()
    |> send_chunked(200)

  with {:ok, conn} <- stream_data(conn),
       {:ok, conn} <- MyApp.ChunkCompressor.chunk(conn, "", :finish) do
    conn
  end
end

def stream_data(conn) do
# Stream from source
|> MyApp.ChunkCompressor.chunk(conn)
end
```

Using this we can finally verify with a browser that we do get all the expected json. Celebration!

### Comparison against uncompressed transfer

Let's take a look at how our compressed data transfer compares against our uncompressed baseline.
Gotta be honest I was quite confident that it would be way faster.

| Compression | Data size | Time taken | Avg. d/l speed | Notes               |
|:----------- | ---------:| ----------:|---------------:|:--------------------|
| No          |     1125M |    0:00:20 |        55.1M/s | Baseline w/ 2 CPUs  |
| Yes         |      295M |    0:00:55 |        5427k/s | Default compression |

Wha? How can it be!? Average download speed is a tenth of the baseline -- WTF!

![George Costanza is also confused](/assets/images/gzip_chunks/george_costanza_wat.jpg)

Very disappointing. But I slowly realized that the overhead of compressing a chunk simply didn't outweigh the size benefit.
I started experiment with the zlib parameters to see if I could improve things:

| Compression | Data size | Time taken | Avg. d/l speed | Notes                                 |
|:----------- | ---------:| ----------:|---------------:|:--------------------------------------|
| Yes         |     346M  |    0:00:35 |         9.9M/s | :best_speed compression level         |
| Yes         |     348M  |    0:00:38 |        9337k/s | Highest mem_level                     |
| Yes         |     755M  |    0:00:35 |        21.5M/s | :huffman_only strategy                |

Turned out it was tough to beat the baseline's 20s time taken. The last option was getting close in download speed but then the compression was garbage. Not worth. I implemented parallel compression, but that wouldn't fly:

```
** (EXIT) an exception was raised:
    ** (ErlangError) Erlang error: :not_on_controlling_process
        :zlib.getStash_nif(#Reference<0.3440369274.760610817.152045>)
        :zlib.restore_progress/2
        :zlib.deflate/3
```

Because zlib streams should only be changed from [one thread](https://zlib.net/zlib_faq.html#faq21).

There's an alternative erlang zlib library called [ezlib](https://github.com/silviucpp/ezlib) "optimized for streaming" that sounded very promising -- unfortunately I couldn't get it to work.

### Conclusion

It seems like the original idea of compressing chunks is not giving enough benefits, the transfer speed is worse than the uncompressed version.
After the fact I guess it simply makes sense, doing work per chunk -- especially computationally intensive work -- inflicts a heavy penalty on the throughput.

There's one more thing I can think of that might help the compression and that is to increase the size of the chunks that we get from the data source (right now they are around 150 - 1000KB). This way `deflate/2` is called fewer times. I could also try smaller values for window bits, but I am not sure that would do much.

All in all this was a "failed" experiment, although fun and I learned some things.

### Future

HTTP/2 does not support chunked transfer encoding (it even forbids it). I don't know how a solution would look like for HTTP/2, but maybe I'll write a follow-up if I get to experiment a bit with that.
