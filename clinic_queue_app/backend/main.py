# main.py
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from typing import List
import json

app = FastAPI()

# uvicorn main:app --reload

# pridaj do websocket pre testing
# print("UPDATE:", index, status)
# print(app_state.slots)


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
            data = await websocket.receive_text()
            payload = json.loads(data)

            print("UPDATE:", payload)

            index = int(payload["index"])
            status = payload["status"]

            slots[index] = status
            print(slots)

            await manager.broadcast({
                "type": "slots",
                "index": index,
                "status": status,
            })

    except WebSocketDisconnect:
        manager.disconnect(websocket)


