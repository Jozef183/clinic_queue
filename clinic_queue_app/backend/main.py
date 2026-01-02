# main.py
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from typing import List
import json

app = FastAPI()

# uvicorn main:app --reload

SLOT_COUNT = 30

# 🔥 server drží CELÝ SLOT, nie len status
slots = [
    {
        "status": "free",
        "name": None,
        "personalId": None,
        "note": None,
    }
    for _ in range(SLOT_COUNT)
]


class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

        # 👈 po pripojení pošli aktuálny stav
        for i, slot in enumerate(slots):
            await websocket.send_json({
                "type": "slots",
                "index": i,
                "slot": slot,
            })

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
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
            raw = await websocket.receive_text()
            payload = json.loads(raw)

            print("UPDATE:", payload)

            if payload.get("type") != "slots":
                continue

            index = payload.get("index")
            slot = payload.get("slot")

            # 🛑 validácia
            if (
                index is None
                or slot is None
                or not isinstance(index, int)
                or not (0 <= index < SLOT_COUNT)
            ):
                print("INVALID PAYLOAD")
                continue

            # 🧠 defaultné hodnoty (ochrana proti None)
            slots[index] = {
                "status": slot.get("status", "free"),
                "name": slot.get("name"),
                "personalId": slot.get("personalId"),
                "note": slot.get("note"),
            }

            # 📢 broadcast všetkým (lekár, TV, pacient)
            await manager.broadcast({
                "type": "slots",
                "index": index,
                "slot": slots[index],
            })

    except WebSocketDisconnect:
        manager.disconnect(websocket)
        print("WS DISCONNECTED")
