#!/usr/bin/env python3
"""Deterministic, local-only Codex app-server fixture for the Qt client tests."""

import json
import os
import sys


def write(value):
    print(json.dumps(value, ensure_ascii=False), flush=True)


def thread(thread_id):
    return {
        "id": thread_id,
        "name": "Conversa anterior" if thread_id == "saved-chat" else "Outra conversa",
        "preview": "Minha cor preferida é azul.",
        "cwd": "/tmp/pragus-source-workspace",
        "source": "cli",
        "createdAt": 1730831100,
        "updatedAt": 1730831111,
        "turns": [],
        "status": {"type": "active" if thread_id == "active-chat" else "idle"},
    }


def turn(turn_id, text, response):
    return {
        "id": turn_id,
        "status": "completed",
        "items": [
            {"id": turn_id + "-user", "type": "userMessage", "content": [{"type": "text", "text": text}]},
            {"id": turn_id + "-assistant", "type": "agentMessage", "text": response},
        ],
    }


for line in sys.stdin:
    request = json.loads(line)
    with open(os.environ["PRAGUS_TEST_RPC_LOG"], "a", encoding="utf-8") as log:
        log.write(json.dumps(request, ensure_ascii=False) + "\n")
    if "id" not in request:
        continue
    method = request.get("method")
    params = request.get("params", {})
    result = {}
    error = None
    if method == "initialize":
        result = {"userAgent": "pragus-test"}
    elif method == "account/read":
        result = {"account": {"type": "chatgpt", "email": "fixture@example.invalid", "planType": "plus"}}
    elif method == "model/list":
        result = {"data": [{"model": "fixture-model", "displayName": "Fixture", "hidden": False,
                            "isDefault": True, "supportedReasoningEfforts": [{"reasoningEffort": "low"}],
                            "defaultReasoningEffort": "low"}], "nextCursor": None}
    elif method == "account/rateLimits/read":
        result = {"rateLimits": {"planType": "plus", "primary": {"usedPercent": 10, "windowDurationMins": 300}}}
    elif method == "thread/list":
        result = {"data": [thread("older-chat" if params.get("cursor") else "saved-chat")],
                  "nextCursor": None if params.get("cursor") else "history-page-2"}
    elif method == "thread/resume":
        if params["threadId"] == "missing-chat":
            error = {"code": -32600, "message": "Conversa não encontrada."}
        else:
            result = {"thread": thread(params["threadId"]), "model": "fixture-model", "reasoningEffort": "low"}
    elif method == "thread/turns/list":
        if params["threadId"] == "legacy-history":
            error = {"code": -32601, "message": "Method not found"}
        elif params["threadId"] == "broken-history":
            error = {"code": -32600, "message": "Histórico indisponível."}
        elif params.get("cursor"):
            result = {"data": [turn("turn-2", "Guarde esta informação.", "Vou manter esse contexto.")], "nextCursor": None}
        else:
            result = {"data": [turn("turn-1", "Minha cor preferida é azul.", "Entendido: azul.")], "nextCursor": "turns-page-2"}
    elif method == "thread/read":
        result = {"thread": thread(params["threadId"])}
        if params.get("includeTurns"):
            result["thread"]["turns"] = [turn("turn-1", "Minha cor preferida é azul.", "Entendido: azul.")]
    elif method == "thread/start":
        result = {"thread": thread("created-chat"), "model": "fixture-model", "reasoningEffort": "low"}
    elif method == "turn/start":
        result = {"turn": {"id": "answer-turn", "status": "inProgress", "items": []}}
    elif method == "turn/interrupt":
        result = {}
    if error:
        write({"id": request["id"], "error": error})
        continue
    write({"id": request["id"], "result": result})
    if method == "turn/start":
        write({"method": "item/agentMessage/delta", "params": {
            "threadId": params["threadId"], "itemId": "answer-item", "delta": "Sua cor preferida é azul."}})
        write({"method": "turn/completed", "params": {
            "threadId": params["threadId"], "turn": {"id": "answer-turn", "status": "completed"}}})
