"""Metro proxy for remote phones: gzip-able bundle responses, everything else passed through."""
import asyncio
import os

import aiohttp
from aiohttp import WSMsgType, web

UPSTREAM = os.environ.get("METRO_UPSTREAM", "http://127.0.0.1:18081")
HOSTS = os.environ.get("PROXY_HOSTS", "127.0.0.1").split(",")
PORT = int(os.environ.get("PROXY_PORT", "8081"))
HOP_BY_HOP = {"connection", "keep-alive", "transfer-encoding", "upgrade", "te", "trailer"}


def upstream_headers(request):
    headers = {k: v for k, v in request.headers.items() if k.lower() not in HOP_BY_HOP}
    if request.path.endswith(".bundle"):
        # Metro skips gzip for multipart progress streams, which is ~6x more bytes over a slow link.
        headers["Accept"] = "*/*"
    return headers


async def proxy(request):
    if request.headers.get("Upgrade", "").lower() == "websocket":
        return await proxy_websocket(request)
    session = request.app["session"]
    async with session.request(
        request.method,
        UPSTREAM + request.path_qs,
        headers=upstream_headers(request),
        data=await request.read() if request.can_read_body else None,
        allow_redirects=False,
    ) as upstream:
        response = web.StreamResponse(status=upstream.status)
        for key, value in upstream.headers.items():
            if key.lower() not in HOP_BY_HOP and key.lower() != "content-length":
                response.headers.add(key, value)
        await response.prepare(request)
        async for chunk in upstream.content.iter_any():
            await response.write(chunk)
        await response.write_eof()
        return response


async def proxy_websocket(request):
    client = web.WebSocketResponse(max_msg_size=0)
    await client.prepare(request)
    session = request.app["session"]
    async with session.ws_connect(UPSTREAM + request.path_qs, headers={"Host": request.host}, max_msg_size=0) as upstream:
        await asyncio.gather(pump(client, upstream), pump(upstream, client), return_exceptions=True)
    await client.close()
    return client


async def pump(source, sink):
    async for msg in source:
        if msg.type == WSMsgType.TEXT:
            await sink.send_str(msg.data)
        elif msg.type == WSMsgType.BINARY:
            await sink.send_bytes(msg.data)
        else:
            break
    await sink.close()


async def open_session(app):
    app["session"] = aiohttp.ClientSession(auto_decompress=False, timeout=aiohttp.ClientTimeout(total=None))
    yield
    await app["session"].close()


app = web.Application(client_max_size=0)
app.cleanup_ctx.append(open_session)
app.router.add_route("*", "/{tail:.*}", proxy)

if __name__ == "__main__":
    web.run_app(app, host=HOSTS, port=PORT)
