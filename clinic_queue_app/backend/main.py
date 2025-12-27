# main.py
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from typing import List

app = FastAPI()

SLOT_COUNT = 30
slots = ["free"] * SLOT_COUNT

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in self.active_connections:
            await connection.send_json(message)

manager = ConnectionManager()

@app.websocket("/ws/queue")
async def queue_ws(websocket: WebSocket):
    await manager.connect(websocket)

    try:
        while True:
            data = await websocket.receive_json()

            if data["type"] == "update":
                index = data["index"]
                status = data["status"]

                slots[index] = status

                # await manager.broadcast({
                #     "type": "state",
                #     "slots": slots
                # })

                await manager.broadcast({
                    "type": "update",
                    "index": index,
                    "status": status
                })

    except WebSocketDisconnect:
        manager.disconnect(websocket)

