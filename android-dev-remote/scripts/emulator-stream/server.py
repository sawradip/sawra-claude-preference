"""Live browser view of the Android emulator: gRPC frames out, taps and keys in."""
import asyncio
import os
import subprocess
from pathlib import Path

import grpc
from aiohttp import WSMsgType, web

import emulator_controller_pb2 as pb
import emulator_controller_pb2_grpc as rpc

HERE = Path(__file__).parent
GRPC_TARGET = os.environ.get("EMULATOR_GRPC", "127.0.0.1:8554")
HOST = os.environ.get("STREAM_HOST", "127.0.0.1")
PORT = int(os.environ.get("STREAM_PORT", "8887"))
FRAME_WIDTH = int(os.environ.get("STREAM_WIDTH", "540"))
KEYCODES = {"back": "KEYCODE_BACK", "home": "KEYCODE_HOME", "recents": "KEYCODE_APP_SWITCH"}


async def index(_request):
    return web.FileResponse(HERE / "index.html")


async def screen(request):
    ws = web.WebSocketResponse(max_msg_size=0)
    await ws.prepare(request)
    async with grpc.aio.insecure_channel(GRPC_TARGET) as channel:
        stub = rpc.EmulatorControllerStub(channel)
        pump = asyncio.create_task(push_frames(stub, ws))
        try:
            async for msg in ws:
                if msg.type == WSMsgType.TEXT:
                    await handle_input(stub, msg.json())
        finally:
            pump.cancel()
    return ws


async def push_frames(stub, ws):
    fmt = pb.ImageFormat(format=pb.ImageFormat.PNG, width=FRAME_WIDTH)
    async for image in stub.streamScreenshot(fmt):
        await ws.send_bytes(image.image)


async def handle_input(stub, event):
    if event["type"] == "key":
        subprocess.run(["adb", "shell", "input", "keyevent", KEYCODES[event["key"]]], check=False)
        return
    pressure = 0 if event["type"] == "up" else 1024
    touch = pb.Touch(x=event["x"], y=event["y"], identifier=0, pressure=pressure)
    await stub.sendTouch(pb.TouchEvent(touches=[touch]))


app = web.Application()
app.add_routes([web.get("/", index), web.get("/ws", screen)])

if __name__ == "__main__":
    web.run_app(app, host=HOST, port=PORT)
